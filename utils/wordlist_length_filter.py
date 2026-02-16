import os
import sys

data_directories = "data/"

def separate_file_by_number_of_chars(num_chars):
    for file_name in os.listdir(data_directories):

        if not file_name.endswith(".txt"):
            continue

        if "less_than" in file_name:
            continue

        pathway = os.path.join(data_directories, file_name)

        output_filename = file_name.replace(
            ".txt", f"_less_than_{num_chars}_chars.txt"
        )
        output_path = os.path.join(data_directories, output_filename)

        print(f"extracting: {file_name}")

        with open(pathway, "r", encoding="latin-1") as infile:
            with open(output_path, "w") as outfile:
                for line in infile:
                    if len(line.strip()) <= num_chars:
                        outfile.write(line)
                
    
def main():
    number_of_chars = int(sys.argv[1])
    separate_file_by_number_of_chars(number_of_chars)
    
    
if __name__ == "__main__":
    main()
