def milliseconds_to_hours_minutes_seconds(milliseconds):
    total_seconds = milliseconds / 1000
    hours = int(total_seconds // 3600)
    minutes = int((total_seconds % 3600) // 60)
    seconds = int(total_seconds % 60)
    milliseconds = int((total_seconds - int(total_seconds)) * 1000)
    return f"{hours:02d}:{minutes:02d}:{seconds:02d},{milliseconds:03d}"

def search_number_in_file(filename, number):
    with open(filename, 'r') as file:
        for line in file:
            if line.strip():  # Skip empty lines
                params = line.split()
                try:
                    if float(params[1]) == number:
                        return params[11]
                except (ValueError, IndexError):
                    continue  # Skip lines that cannot be converted to floats or don't have enough parameters
    return None

filename = "VBOX0001.vbo"  # Update with the relevant VBO file name
number_to_search = float(input("Enter a UTC time to search (example enter 133020.10 to seek 13:30:20.10 UTC time): "))

result = search_number_in_file(filename, number_to_search)
if result:
    print("\nTime lock is (copy and paste the following into 'Jump to Time' VLC plugin):\n\n", milliseconds_to_hours_minutes_seconds(int(result)))
else:
    print("Number not found in the file.")