//Generate stacks from GE data
// each channel, field is combined to a timelapse, currently wells are not correctly transferred from A1, A2 to numbering system used by ScanR. 
// TBD: adapt for 3D
// TBD: check what kind of timestamps endings are possible.
//UZ, Center for Microscopy -- November 2021

print("\\Clear");
run("Input/Output...", "jpeg=85 gif=-1 file=.txt use_file");//sets the output from the result window to not include any headers, row indication...

//set some initial variables
zsteps = newArray(); //z steps
inputDirs = newArray(); //store all input directories
pathOrig = newArray(); //store all pathnames of the whole sequence as stored in the filesystem
suffix = ".tif"; //suffix of files to be analyzed and converted to a 
filenameSplitter = " - ()"; //identifier to split filenames for channels

//Ask for some parameters
//#@ String (visibility=MESSAGE, value="Date: (optional) ....................", required=false) msg0
//#@ Date(label="Date:", "**.**.****", required=false) parameterDate 
#@ String (visibility=MESSAGE, value="Sample: (will be used to label the files generated.............", required=false) msg1
#@ String(label="Sample:", "sample name", required=true) parameterSample 
#@ String (visibility=MESSAGE, value="Please select the output format...............", required=false) msg2
#@ String (choices={"Export as a stack", "Export as ScanR compatiple files"}, style="radioButtonHorizontal", required=true) parameterTimelapse
#@ String (visibility=MESSAGE, value="Please select all directories with files to be merged...........", required=false) msg3
#@ File[] (label="Select some directories", style="directories", required=true) directoriesIn //input directories
#@ String (visibility=MESSAGE, value="Please select an output directory...........", required=false) msg4
#@ File (label="Select an output directory", style="directory", required=true) directoryOut //output directory

//allow user to re-sort the input directories to adjust the timelapse sequence
if (directoriesIn.length>1) {
	Dialog.create("Sequence of the timelapse");
	Dialog.addMessage("Select the sequence of directories to be merged into one timelapse dateset");
	for (i = 0; i < directoriesIn.length; i++) {
		Dialog.addChoice(i+1, directoriesIn, directoriesIn[i]);
	}
	Dialog.show();
	for (i = 0; i < directoriesIn.length; i++) {
		inputDirs = Array.concat(inputDirs,Dialog.getChoice());
	}
} else {
	inputDirs = directoriesIn;
}
print("\n------------------------assembling information about the dataset------------------------");

print("\nExport of data as:");
print(parameterTimelapse);
if (indexOf(parameterTimelapse, "ScanR") >=0) {
	setBatchMode(true);
}

//get all pathnames as stored in the filesystem
for (i = 0; i < inputDirs.length; i++) {
	files = getFileList(inputDirs[i]);
	//print(files.length);
	for (f = 0; f < files.length; f++) {
		pathOrig = Array.concat(pathOrig,inputDirs[i]+"\\"+files[f]);
	}
}


print("\nInput Directories:");
Array.print(inputDirs);//prints the input directories to console for debugging

//store information about the dataset, analyze all filenames (based on:
//B - 02(fld 1 wv 473 - Green1 time 02 - 1800000ms).tif

//find channels written in the filename 'wv'; only the first sequence / directory is analyzed - the others must have the same organization
channels = newArray(); //channels
s = 5; //where to split channels
channels=processFolder(inputDirs[0], channels, s);
channels = stripArray(channels);
print("\nChannels:");
Array.print(channels);

//find channel names written in the filename; only the first sequence / directory is analyzed - the others must have the same organization
channels_names = newArray(); //channel names
s = 6; //where to split channel names
channels_names=processFolder(inputDirs[0], channels_names, s);
channels_names = stripArray(channels_names);
print("\nChannel names:");
Array.print(channels_names);

//find rows
rows = newArray(); //rows
s = 0; //where to split channels; only the first sequence / directory is analyzed - the others must have the same organization
rows=processFolder(inputDirs[0], rows, s);
rows=stripArray(rows);
print("\nRows:");
Array.print(rows);

//find columns
columns = newArray(); //columns
s = 1; //where to split channels; only the first sequence / directory is analyzed - the others must have the same organization
columns=processFolder(inputDirs[0], columns, s);
columns=stripArray(columns);
print("\nColumns:");
Array.print(columns);

//find fields
fields = newArray(); //fields
s = 3; //where to split fields; only the first sequence / directory is analyzed - the others must have the same organization
fields=processFolder(inputDirs[0], fields, s);
fields=stripArray(fields);
print("\nFields:");
Array.print(fields);


//find timepoints
//timepoints = newArray(); //timepoints - list of all timepoints as found in the original list of files
//s = 8; //where to split channels; only the first sequence / directory is analyzed - the others must have the same organization
//for (d = 0; d<inputDirs.length; d++) {
	//timepoints=processFolder(inputDirs[d], timepoints, s);
	//columns=stripArray(columns);
//}
n=1; //counter
nTotal=rows.length*columns.length*fields.length*channels.length;
print("\n------------------------putting your sequence together------------------------");
//generate a variable which can be used to store a text file, to open images, stacks, etc
//all sequences / directories are analyzed - store the timepoints and timestamp in a sequence identical to the filenames
for (row = 0; row < rows.length; row++) {
	//Columns
	for (col = 0; col < columns.length; col++) {
		//fields
		for (field = 0; field < fields.length; field++) {
			//channels
			for (ch = 0; ch < channels.length; ch++) {
				//assemble a new sorted filelist: Row>Columns>Fields>Channels: all files are assembled from all directories, files are already sorted due to the timestamp correctly
				pathList = newArray(); //new array to store all files as a path - will be erased for each dataset
				run("Clear Results");
				for (i = 0; i < inputDirs.length; i++) {
					//walk through the original pathlist and add files matching the matched files to a new sorted list
					for (f = 0; f < pathOrig.length; f++) {
						//discriminate also for files with and without the time component
						if (f==0 && indexOf(pathOrig[f], "time")>=0) {
							matchingPart =inputDirs[i] + "\\" + rows[row] + " - " + columns[col] + "fld " + fields[field] + " wv " + channels[ch] + " - " + channels_names[ch] + " time ";
						} else if (f==0) {
							matchingPart =inputDirs[i] + "\\" + rows[row] + " - " + columns[col] + "fld " + fields[field] + " wv " + channels[ch] + " - " + channels_names[ch];
						}
						if (indexOf(inputDirs[i] + "\\" + replace(pathOrig[f], "(", ""), matchingPart)>=0) {
							if (endsWith(pathOrig[f], suffix)) {
								file = pathOrig[f];
								//print(file);
								pathList = Array.concat(pathList,file);
							}
						}
					}
				}//sequence has been put together - let's generate a data set - by this inconsitencies in files of large datasets do not throw an error
				//Generating a dataset
				sField = toString(field); while (sField.length() < 5) {sField = "0" + sField;} //compute strings (string.format currently does not work)
				sWell = toString(1 + col + row * columns.length); while (sWell.length() < 5) {sWell = "0" + sWell;}
				nameStack = parameterSample +"--W" + sWell + "--P" + sField + "--" + channels_names[ch];
				print("------------------------generating " + nameStack + " (" + n + " of " + nTotal + " )------------------------");
				for (t = 0; t < pathList.length; t++) {
					setResult("Column", t, pathList[t]);//pushes the pathname to the result window - results window gets populated with all paths of the data set
					if (indexOf(parameterTimelapse, "ScanR") >=0) {
						//open(pathList[t]);
						//save as tiff files for scanR, adapt name if needed
						sTime = toString(t); while (sTime.length() < 5) {sTime = "0" + sTime;}
						nameFile = parameterSample+"--W" + sWell + "--P" + sField + "--Z00000--T" + sTime + "--" + channels_names[ch];
						//saveAs("tif", directoryOut + "\\" + nameFile);
						//close();
						File.copy(pathList[t], directoryOut + "\\" + nameFile + ".tif");
						}
					}
				//Results window is populated with all filenames
				if (indexOf(parameterTimelapse, "stack")>=0) {
					//generate a stack
					saveAs("Results", directoryOut + "\\" + nameStack + ".txt");
					run("Stack From List...", "open=[" + directoryOut + "\\" + nameStack + ".txt" + "] use");
					saveAs("tiff", directoryOut + "\\" + nameStack + ".tif");
					close();
				}
				n=n+1;
			}
		}
	}
}

//clean up
run("Clear Results");
setBatchMode(false);
print("\n------------------------Finished------------------------");

//define functions
function stripArray (arr) {
	Array.sort(arr);
	for (i = 0; i < arr.length -1; i++) {
		if (arr[i]==arr[i+1]) {
			arr = Array.deleteIndex(arr, i+1);
			i= i-1;
		}
	}	
	return arr;
}
//extract information from filenames
function processFolder(input, arr, s) {
	list = getFileList(input);
		for (i = 0; i < list.length; i++) {
			//ignore all non tiff files that may be in the folder
			if (endsWith(list[i], suffix)) {
				filenameSplit = split(list[i], filenameSplitter);
				//store all information sequentially in an array
				arr = Array.concat(arr, filenameSplit[s]);
			}
		}
	return arr;	
}
