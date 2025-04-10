#!/bin/bash

#Author: Jijin Shaji
#Version: 1.0
#Description: to fetch the users from the linux machine
#Date: 08-Apr-2025

#Version: 1.1
#Description: Check in detail for the ID set with password along with other users
#Date: 10-Apr-2025

# Function to convert a date to Unix timestamp
convert_to_timestamp() {
    local date_str="$1"
    # Use `date` to parse the date string into a Unix timestamp
    date -d "$date_str" +%s 2>/dev/null || echo "never"
}

# Generate the output filename
hostname=$(hostname)
todays_date=$(date +"%Y-%m-%d")
output_file="${hostname}_${todays_date}.txt"

# Clear the output file before appending new data
> "$output_file"

# Log users with /bin/bash and /sbin/nologin shells
grep "/bin/bash$" /etc/passwd > login__users.txt
grep "/sbin/nologin$" /etc/passwd > nologin__users.txt

# Append login__users.txt and nologin__users.txt to the output file
echo "----------------------------------------" >> "$output_file"
echo "Users with /bin/bash Shell" >> "$output_file"
echo "----------------------------------------" >> "$output_file"
cat login__users.txt >> "$output_file"

echo "----------------------------------------" >> "$output_file"
echo "Users with /sbin/nologin Shell" >> "$output_file"
echo "----------------------------------------" >> "$output_file"
cat nologin__users.txt >> "$output_file"

# Arrays to store users with and without passwords
no_password_users=()
password_set_users=()

# Fetch all users with UID >= 1000 (real users)
# Use input redirection to avoid subshell issues
grep -E '^([^:]+:){2}[0-9]{4}' /etc/passwd > users.txt
while IFS=: read -r username _ _ _ _ _ _; do
    # Check if the user has a password set
    password_status=$(sudo grep "^$username:" /etc/shadow | cut -d: -f2)

    if [[ -z "$password_status" || "$password_status" == "*" || "$password_status" == "!!" ]]; then
        # Password is not set or locked
        no_password_users+=("$username")
    else
        # Password is set
        password_set_users+=("$username")
    fi
done < users.txt
rm users.txt

# Print users with no password set or locked passwords to the output file
echo "----------------------------------------" >> "$output_file"
echo "Users with No Password Set or Locked Passwords" >> "$output_file"
echo "----------------------------------------" >> "$output_file"
for user in "${no_password_users[@]}"; do
    echo "User: $user - No password set or password is locked" >> "$output_file"
done

# Print users with passwords set to the output file
echo "----------------------------------------" >> "$output_file"
echo "Users with Passwords Set" >> "$output_file"
echo "----------------------------------------" >> "$output_file"
for user in "${password_set_users[@]}"; do
    echo "User: $user - Password is set" >> "$output_file"
done

# Check compliance for users with passwords set
echo "----------------------------------------" >> "$output_file"
echo "Users with Password Expiration Not Compliant" >> "$output_file"
echo "----------------------------------------" >> "$output_file"
for user in "${password_set_users[@]}"; do
    # Get password expiration policy
    chage_output=$(sudo chage -l "$user")

    # Parse fields from chage output
    last_password_change=$(echo "$chage_output" | grep "Last password change" | awk -F': ' '{print $2}')
    password_expires=$(echo "$chage_output" | grep "Password expires" | awk -F': ' '{print $2}')
    password_inactive=$(echo "$chage_output" | grep "Password inactive" | awk -F': ' '{print $2}')
    account_expires=$(echo "$chage_output" | grep "Account expires" | awk -F': ' '{print $2}')

    # Determine compliance
    non_compliant=false

    # Check if "Password expires" or "Password inactive" or "Account expires" is set to never
    if [[ "$password_expires" == "never" || "$password_inactive" == "never" || "$account_expires" == "never" ]]; then
        non_compliant=true
    fi

    # Compare "Password expires" with "Last password change"
    if [[ "$last_password_change" != "password must be changed" && "$password_expires" != "never" ]]; then
        # Convert dates to Unix timestamps
        last_change_ts=$(convert_to_timestamp "$last_password_change")
        password_expires_ts=$(convert_to_timestamp "$password_expires")

        if [[ "$last_change_ts" != "never" && "$password_expires_ts" != "never" ]]; then
            # Calculate the difference in days
            diff_seconds=$((password_expires_ts - last_change_ts))
            diff_days=$((diff_seconds / 86400)) # 86400 seconds in a day

            if ((diff_days > 90)); then
                non_compliant=true
            fi
        fi
    fi

    # Print non-compliant users to the output file
    if $non_compliant; then
        echo "User: $user" >> "$output_file"
        echo "$chage_output" >> "$output_file"
        echo "----------------------------------------" >> "$output_file"
    fi
done

# Notify the user where the output is saved
echo "Output saved to: $output_file"
