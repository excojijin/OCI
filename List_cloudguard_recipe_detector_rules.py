'''
Author: Exco
Date: 12-03-25
Description: Fetching cloudguard recipe and the rule status from root compartment using DEFAULT profile
Version: 1.0
 
'''
import csv
import oci
 
# Initialize OCI clients
config = oci.config.from_file()  # Load OCI config from ~/.oci/config
cloud_guard_client = oci.cloud_guard.CloudGuardClient(config)
 
# Specify compartment OCID (replace with your compartment OCID)
compartment_id = "ocid1.compartment.oc1..<your_compartment_ocid>"
 
# Fetch all recipes in the compartment
recipes_collection = cloud_guard_client.list_detector_recipes(compartment_id=compartment_id).data
recipes = recipes_collection.items  # Access the 'items' attribute to get the list of recipes
 
# Prepare CSV file
csv_filename = "cloud_guard_recipes_and_rules.csv"
csv_columns = ["Recipe Name", "Detector Rule", "Risk Level", "Status", "Settings Configured", "Conditional Group"]
 
with open(csv_filename, mode="w", newline="") as csv_file:
    writer = csv.DictWriter(csv_file, fieldnames=csv_columns)
    writer.writeheader()
 
    # Iterate through each recipe
    for recipe in recipes:
        recipe_name = recipe.display_name
 
 
        # Fetch detector rules for the current recipe
        detector_rules_collection = cloud_guard_client.list_detector_recipe_detector_rules(
            detector_recipe_id=recipe.id, compartment_id=compartment_id
        ).data
        detector_rules = detector_rules_collection.items  # Access the 'items' attribute to get the list of rules
        print(detector_rules)
 
        # Extract details for each detector rule
        for rule in detector_rules:
            # Safely access attributes with default values
            risk_level = getattr(rule.detector_details, "risk_level", "N/A")
            is_enabled = "Enabled" if getattr(rule.detector_details, "is_enabled", False) else "Disabled"
            # Check if is_configuration_allowed is null or not
            is_configuration_allowed = (
                "Yes" if getattr(rule.detector_details, "is_configuration_allowed", None) else "No"
            )
 
            # Check if condition is null or not
            condition = (
                "Yes" if getattr(rule.detector_details, "condition", None) else "No"
            )
 
            rule_details = {
                "Recipe Name": recipe_name,
                "Detector Rule": rule.display_name,
                "Risk Level": risk_level,
                "Status": is_enabled,
                "Settings Configured": is_configuration_allowed,
                "Conditional Group": condition,
            }
            writer.writerow(rule_details)
 
print(f"Data exported successfully to {csv_filename}")
