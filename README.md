# Calvary Video converter
Replaces blank (black) sections of a video file with transparency with fade in and out. It is ment to process screen recordings from ProPresenter6 software. The resulting video file is automaticly uploaded to WeTransfer file sharing service and the link to the correspondings files are posted privatly on a pastebin account.  
The terminal from which the script was launched is closed automaticly upon completion.  
The output video file is encoded in vp9 because it provides support for transparency.

# Instalation
ffmpeg version >= 4 must be installed and available in `PATH`.
It is recomended but not necessary to place the scripts contained in this directory in your `PATH` (the following instructions assume so).  
Accounts must be created to use WeTransfer and pastbin. The corresponding API keys and credentials must be placed in a file named `creds.sh`. A template `creds_template.sh` is provided for reference.

# Usage
To process a video file and upload it all in one operation use:  
```calvary_video.sh input_file.mov```  

To only process a video without upload use:  
```convert.sh input_file.mov output_file.mkv```  

To upload a file to WeTransfer and then post the link to pastebin use:  
```curl.sh log_file video_file.mkv```

# Working directories
A hidden directory `.ffmpeg_data/` is created within the script directory. It will contain all the temporary files needed for the video processing. These files are automaticaly overwritten at each execution, no manual intervention required.  
Another hidden directory `.ffmpeg_logs/` will contain all the logs named `YYYY-MM-DD_HH-MM.log` for debugging purposes.

# Author
Simon Brown
