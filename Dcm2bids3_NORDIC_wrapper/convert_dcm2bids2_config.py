import argparse
import json

def rename_keys(data):
    key_mapping = {
        "dataType": "datatype",
        "modalityLabel": "suffix",
        "customEntities": "custom_entities",
        "customLabels": "custom_entities",
        "sidecarChanges": "sidecar_changes",
        "caseSensitive": "case_sensitive",
        "defaceTpl": "post_op",
        "searchMethod": "search_method",
    }

    if isinstance(data, dict):
        updated_data = {}
        for key, value in data.items():
            if key in key_mapping:
                updated_key = key_mapping[key]
                updated_data[updated_key] = rename_keys(value)
            elif key == "intendedFor":
                # Remove the "intendedFor" key and its value
                continue
            else:
                updated_data[key] = rename_keys(value)
        return updated_data
    elif isinstance(data, list):
        return [rename_keys(item) for item in data]
    else:
        return data

def main():
    parser = argparse.ArgumentParser(description="Rename and filter keys in a JSON file")
    parser.add_argument("input_file", help="Input JSON file path")
    parser.add_argument("output_file", help="Output JSON file path")
    args = parser.parse_args()

    try:
        with open(args.input_file, "r") as f:
            json_data = json.load(f)
            updated_data = rename_keys(json_data)

        with open(args.output_file, "w") as f:
            json.dump(updated_data, f, indent=4)

        print(f"File '{args.input_file}' processed and saved as '{args.output_file}'.")

    except FileNotFoundError:
        print(f"Error: File not found: {args.input_file}")
    except json.JSONDecodeError:
        print(f"Error: Invalid JSON format in file: {args.input_file}")
    except Exception as e:
        print(f"An error occurred: {str(e)}")

if __name__ == "__main__":
    main()
