@set @foo=1 /*
@echo off
cscript %0 //E:JScript //Nologo
goto end
*/;

var adTypeBinary = 1;
var adSaveCreateOverWrite = 2;

var SRC = "http://pci-ids.ucw.cz/v2.2/pci.ids.gz";
var DEST = "pci.ids.gz";

var XMLHTTP = new ActiveXObject("MSXML2.XMLHTTP");
XMLHTTP.open("GET", SRC, false);
XMLHTTP.send();

if (XMLHTTP.Status != 200) {
    WScript.Echo("Error " + XMLHTTP.Status + " while downloading: " + XMLHTTP.StatusText);
} else {
    var Stream = new ActiveXObject("ADODB.Stream");
    Stream.Type = adTypeBinary;
    Stream.Open();

    Stream.Write(XMLHTTP.ResponseBody);
    Stream.SaveToFile(DEST, adSaveCreateOverWrite);
    Stream.Close();
    WScript.Echo("Done.");
}

/*
:end
rem */
