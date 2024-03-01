# VBOX HD Sync

## Notes
- Windows only
- At the moment the vbo file name is hardcoded so you will need to update the file name in the python script before running!

## Installation
- Need Python3 installed
- Need VLC media player installed 
- Copy the VBOX HD Sync.lua file to the following directory (C:\Program Files (x86)\VideoLAN\VLC\lua\extensions)
- Make a New Folder and copy across the VBO file, the mp4 file, and the HD_Sync.py file (so they are all in the same)

## Usage
- Load the HD files into VBTS and find a UTC time of interest (in the data or on the video overlay if it is present)
- Run the Python script from command prompt "Python HD_Sync.py"
- Enter the UTC time "example "174536.200"
- If a valid time is found the script will return a video frame time associated with that VBO or Graphic overlay data sample
- Copy the video frame time 
- Run VLC and load in the .mp4 video file
- In VLC player click 'View' > 'VBOX HD Sync' 
- In the popup window paste the video frame time and press the '>> Set time' button
- Hopefully the video frame presented will be at the same point of the UTC time VBO data point or/and in the graphics overlay


