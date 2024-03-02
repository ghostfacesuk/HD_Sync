# VBOX HD Sync

## Notes
- Windows only
- Uses the tkinter library for file selection

## Installation
- Need Python3 installed
- Need VLC media player installed 
- Copy the VBOX HD Sync.lua file to the following directory (C:\Program Files (x86)\VideoLAN\VLC\lua\extensions)

## Usage
- Load the VBOX HD files into VBTS and find a UTC time of interest (in the data or on the video overlay if it is present)
- Run the Python script from command prompt "Python HD_Sync.py"
- Enter the UTC time "example "174536.200"
- If a valid time is found the script will return a video frame time associated with that VBO or Graphic overlay data sample
- Copy the video frame time 
- Run VLC and load in the .mp4 video file
- In VLC player click 'View' > 'VBOX HD Sync' 
- In the popup window paste the video frame time and press the '>> Set time' button
- Hopefully the video frame presented will be at the same point of the UTC time VBO data point or/and in the graphics overlay