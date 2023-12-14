import re
import glob
from pathlib import Path
import shutil
import subprocess

this_file_path = Path(__file__).resolve().parent

def replace_strings_in_file(file_path, replacements_dict, output_file_path):
    """
    This does a search and replace on a text file and replaces
    tokens if there is a corresponding replacements dict entry
    """
    try:
        with open(file_path, 'r') as file:
            file_content = file.read()

            # Perform replacements
            for old_string, new_string in replacements_dict.items():
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


def find_source_files(input_path_root, input_path_extensions):
    """
    Find all source files recursively according to input_path_extensions
    """
    source_files = []
    for extension in input_path_extensions:
        source_list = glob.glob(str(input_path_root.resolve()) + f"/**/*{extension}", recursive=True)
        source_list = [path for path in source_list if not "/host/" in path] # remove /host dir
        source_files.extend(source_list)

    return source_files

def build_replacement_dict(substitutions, source_files, xua_copy_suffix, additional=None):
    """
    from the list of copied source files (processes h files in particular),
    a list of substitutions (symbols) and the required name mangling suffix,
    it builds a dict of replacements
    """
    # Empty text replacement dict
    replacements = {}

    # Add all substitutions to replacements
    for substitution in substitutions:
        print("***", substitution)
        replacements[substitution] = substitution + xua_copy_suffix

    # Add all include file names to replacements
    for source_file in source_files:
        if ".h" in Path(source_file).name:
            h_file = Path(source_file).name
            new_h_file = h_file.split(".")[0] + xua_copy_suffix + ".h"
            replacements[h_file] = new_h_file

    if additional is not None:
        for key in additional.keys():
            replacements[key] = additional[key]

    return replacements

def duplicate_source(source_files, output_dir, xua_copy_suffix, replacements=None, copy=False):
    """
    Copies a bunch of source files to a single output dir.
    If copy is True it does a straight copy, if not, then
    it processes the contents to name mangle.
    """
    Path(output_dir).mkdir(parents=True, exist_ok=True)

    # Do the read->modify->write
    for source_file in source_files:
        target_file = output_dir / (Path(source_file).stem + xua_copy_suffix + Path(source_file).suffix)
        
        if copy:
            print(f"Copying: {source_file}")
            shutil.copy2(source_file, target_file)
        else:
            print(f"Copying and modifying: {source_file}")
            replace_strings_in_file(source_file, replacements, target_file)

def build_source():
    """
    Run xmake and grab stderr. stdio goes to the console
    """
    try:
        subprocess.run("xcc", capture_output=True)
    except:
        assert False, "Please ensure XMOS tools are sourced"

    cmd = "xmake clean"
    subprocess.run(cmd.split(), stderr=subprocess.PIPE, text=True)

    cmd = "xmake -j"
    result = subprocess.run(cmd.split(), stderr=subprocess.PIPE, text=True)

    return result.stderr

def extract_symbol_clashes(stderr):
    """
    Parse the linker output and grab duplicate symbols
    """
    substitutions = []

    for line in stderr.split("\n"):
        if "'" in line:
            if not "globound" in line:
                token = line.split("'")[1]
                if not "." in token:
                    substitutions.append(token)

    return substitutions


if __name__ == "__main__":
    input_path_root = this_file_path / "../../../lib_xua"
    output_dir = this_file_path / "../src/xua2"
    input_path_extensions = [".xc", ".c", ".h"]
    xua_copy_suffix = "_2"
    # Manually add new "xua_conf.h" to modifications
    additional = {}
    additional["xua_conf.h"] = "xua_conf_2.h"


    source_files = find_source_files(input_path_root, input_path_extensions)
    # Now build a copy that will clash
    duplicate_source(source_files, output_dir, xua_copy_suffix, replacements=None, copy=True)
    stderr = build_source()
    # Parse the clashing symbols and build a set of replacements
    substitutions = extract_symbol_clashes(stderr)
    replacements_dict = build_replacement_dict(substitutions, source_files, xua_copy_suffix, additional=additional)
    # Now re-copy with search and replace and build
    duplicate_source(source_files, output_dir, xua_copy_suffix, replacements_dict=replacements_dict, copy=False)
    stderr = build_source()


