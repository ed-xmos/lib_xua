import re
import glob
from pathlib import Path
import shutil

def replace_strings_in_file(file_path, replacements, output_file_path):
    try:
        with open(file_path, 'r') as file:
            file_content = file.read()

            # Perform replacements
            for old_string, new_string in replacements.items():
                # Use regular expression with word boundaries to match whole words only
                pattern = r'\b' + re.escape(old_string) + r'\b'
                file_content = re.sub(pattern, new_string, file_content)

        # Write modified content to a new file
        with open(output_file_path, 'w') as output_file:
            output_file.write(file_content)
            print(f"Replacements completed. Modified content saved to '{output_file_path}'.")

    except FileNotFoundError:
        print("File not found. Please provide a valid file path.")
    except Exception as e:
        print(f"An error occurred: {str(e)}")

this_file_path = Path(__file__).resolve().parent
input_path_root = this_file_path / "../../../lib_xua"
input_path_extensions = [".xc", ".c", ".h"]
output_dir = this_file_path / "../../../lib_xua/src2"
Path(output_dir).mkdir(parents=True, exist_ok=True)

replacements = ["", ""]

source_files = []
for extension in input_path_extensions:
    source_list = glob.glob(str(input_path_root.resolve()) + f"/**/*{extension}", recursive=True)
    source_list = [path for path in source_list if not "/host/" in path] # remove /host dir
    source_files.extend(source_list)

for source_file in source_files:
    target_file = output_dir / (Path(source_file).stem + "2" + Path(source_file).suffix)
    shutil.copy2(source_file, target_file)

# # Call function to perform replacements and save to a new file
# for i, o in zip(file_paths, output_file_paths):
#     replace_strings_in_file(i, replacements, o)