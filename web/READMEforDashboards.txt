TO use Different webportal dashboards:

There are different dashboards that can change the amount of data shown on the main page
Some want more, some want less ( I like less clicking buttons,  but more..... )
how this will work currently ( still developing )

web\index.html is the page the webportal access ( IP adress:4000 ) locally

index.html is already active in that folder, it is the base format. ( identical to indexORIG.html )
to use any OTHER "style" of dashboard you can do this a few ways
  - rename the version you want to "index.html" and overwrite index.html
  IF you ever want to go back, rename indexORIG.html to "index.html" and overwrite index.html
  - PROBLEM with that option, you lose the files you rename, as backups. 
  So, make a COPY of the style of index you want. then rename the COPY to "index.html" and overwrite index.html
  this way you will retain all styles and can jump between them


indexORIG.html
  - original dashboard, no changes. kept for reverting to standard dash
  - I tend to edit alot and sometime cant return to a working version so I save an ORIG file


indexExtended.html 
  - Adds device(s) table to main dashboard page ( fan speeds, temps, clocks )
  - Removes "2nd bench/ 2nd algo/ 2nd speed" portions of main rig/computer
  
