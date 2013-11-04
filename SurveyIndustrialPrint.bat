@ECHO OFF
:: Process extracts the Survey Industrial Print


SET "LogErrFileName=SurveyIndustrialPrint"

ECHO Running batch Survey Industrial Print ...

CALL \\TorCwiDev01\BatchFiles\Publication\BatchInclude\MSDosServerTest.bat

SET "StartDateTime=%DateTime%"
SET "ProductType=SurveyIndustrial"
SET "ProcessName=SurveyIndustrialPrint"
SET "BatchSubDir=survey"
SET "XmlSubDir=survey"
SET "ErrorFileName=siptmp.err"
SET /a "ErrLevel=0"
SET "Message=%ProductType%: BUILD SUCCESSFUL"
SET "MaxByteSize=2000"
SET "ExtractID=291"
SET "Path2BatchMessage=See file %BatchPath%\%BatchSubDir%\%ProcessName%.bat for location of error."

ECHO ============================================================================================== >> "%LogPath%\%LogErrFileName%%DateToday%.log"
ECHO [%DATE:~-4,4%-%DATE:~-10,2%-%DATE:~-7,2% %TIME%] STARTTIME OF %ProductType% >> "%LogPath%\%LogErrFileName%%DateToday%.log"

IF EXIST "%BatchPath%\%BatchSubDir%\%ErrorFileName%" DEL /q "%BatchPath%\%BatchSubDir%\%ErrorFileName%"
IF EXIST "%OutputPath%\%ProductType%*.xml" DEL /q "%OutputPath%\%ProductType%*.xml"
IF EXIST "%OutputPath%\%ProductType%.xml" DEL /q "%OutputPath%\%ProductType%.xml"
IF EXIST "%XMLPath%\%XmlSubDir%\%ProductType%.xml" DEL /q "%XMLPath%\%XmlSubDir%\%ProductType%.xml"
IF EXIST "%XMLPath%\%XmlSubDir%\%ProductType%Sed.xml" DEL /q "%XMLPath%\%XmlSubDir%\%ProductType%Sed.xml"
IF EXIST "%XMLPath%\%XmlSubDir%\%ProductType%.xml" DEL /q "%XMLPath%\%XmlSubDir%\%ProductType%.xml"
IF EXIST "%XMLPath%\%XmlSubDir%\%ProductType%NoCrop.pdf" DEL /q "%XMLPath%\%XmlSubDir%\%ProductType%NoCrop.pdf"
IF EXIST "%XMLPath%\%XmlSubDir%\%ProductType%.ps" DEL /q "%XMLPath%\%XmlSubDir%\%ProductType%.ps"
IF EXIST "%XMLPath%\%XmlSubDir%\%ProductType%.pdf" DEL /q "%XMLPath%\%XmlSubDir%\%ProductType%.pdf"

%EXEPath%\XMLCreator %ExtractID%
IF %ERRORLEVEL% NEQ 0 (
  :: If error generated from XMLCreator process, email notification is already sent from XMLCreator.exe so don't want to send another one. Just exit.
  SET /a "ErrLevel=0"
  SET "Message=##ERROR## %ProductType%: XMLCreator failed while generating XML file. Email notification should have been sent from XMLCreator.exe. %Path2BatchMessage%"
  GOTO ExitBatch
)

XCOPY /Y "%OutputPath%\%ProductType%*.xml" %OutputPath%\Backup\Publication >NUL
REN "%OutputPath%\%ProductType%*.xml" %ProductType%.xml

"%SedExe%" -f %XMLPath%\process\pdfprint_character.sed %OutputPath%\%ProductType%.xml > %XMLPath%\%XmlSubDir%\%ProductType%Sed.xml 2>> %BatchPath%\%BatchSubDir%\%ErrorFileName%
IF %ERRORLEVEL% NEQ 0 (
  SET /a "ErrLevel+=1"
  SET "Message=##ERROR## %ProductType%: Sed - there was a converting to PDF characters. %Path2BatchMessage%"
  GOTO ExitBatch
)

java -Xms1024M -Xmx1024M -jar "c:\program files\saxon\saxon.jar" -warnings:silent -o:"%XMLPath%\%XmlSubDir%\%ProductType%PreProcess.xml" %XMLPath%\%XmlSubDir%\%ProductType%Sed.xml "%XMLPath%\pre-process\wrapper_survey_printpdf.xsl" 2>> %BatchPath%\%BatchSubDir%\%ErrorFileName%
IF %ERRORLEVEL% NEQ 0 (
  SET /a "ErrLevel+=1"
  SET "Message=##ERROR## %ProductType%: Saxon - there was a problem pre-processing the file. %Path2BatchMessage%"
  GOTO ExitBatch
) 

CALL "c:\program files\xep\xep" -xml %XMLPath%\%XmlSubDir%\%ProductType%PreProcess.xml -xsl %XMLPath%\%XmlSubDir%\pdf\wrapper_survey.xsl -ps %XMLPath%\%XmlSubDir%\%ProductType%.ps 2>> %BatchPath%\%BatchSubDir%\%ErrorFileName% 1>NUL
IF %ERRORLEVEL% NEQ 0 (
  SET /a "ErrLevel+=1"
  SET "Message=##ERROR## %ProductType%: XEP - there was a problem creating the PostScript file. %Path2BatchMessage%"
  GOTO ExitBatch
)

"%ProgramFileDir%\gs\bin\gswin32c" -sDEVICE=pdfwrite -dCompatibilitylevel=1.4 -o%XMLPath%\%XmlSubDir%\%ProductType%NoCrop.pdf %XMLPath%\%XmlSubDir%\%ProductType%.ps 2>> %BatchPath%\%BatchSubDir%\%ErrorFileName% 1>NUL
IF %ERRORLEVEL% NEQ 0 (
  SET /a "ErrLevel+=1"
  SET Message=##ERROR## %ProductType%: GhostScript - there was a problem creating the "pre-cropmark" PDF file. %Path2BatchMessage%
  GOTO ExitBatch
) 

"%ProgramFileDir%\pdftk\bin\pdftk.exe" %XMLPath%\%XmlSubDir%\%ProductType%NoCrop.pdf background %XMLPath%\images\survey\SurveyCropMark.pdf output %XMLPath%\%XmlSubDir%\%ProductType%.pdf 2>> %BatchPath%\%BatchSubDir%\%ErrorFileName% 1>NUL
IF %ERRORLEVEL% NEQ 0 (
  SET /a "ErrLevel+=1"
  SET "Message=##ERROR## %ProductType%: PdkTk - there was a problem adding the cropmarks to the PDF file. %Path2BatchMessage%"
  GOTO ExitBatch
) 

:: returns a count of the number of 0 byte txt files
CALL %BatchPath%\BatchInclude\CountFilesBySize.bat %XMLPath%\%XmlSubDir% %ProductType%.pdf 0 EQU >NUL
IF %ERRORLEVEL% NEQ 0 (
  IF %ERRORLEVEL% EQU -1 (
    SET /a "ErrLevel+=1"
    SET "Message=##ERROR## %ProductType%: File^(s^) cannot be found in specified directory. No files delivered. %Path2BatchMessage%"
    GOTO ExitBatch
  )
  :: If there are any 0 byte files then generate error and exit batch.
  IF %ERRORLEVEL% GTR 0 (
    SET /a "ErrLevel+=1"
    SET "Message=##ERROR## %ProductType%: One or more of the files tested are size of 0 byte. No files were delivered. %Path2BatchMessage%"
    GOTO ExitBatch
  )
)

XCOPY /Y "%XMLPath%\%XmlSubDir%\%ProductType%.pdf" "%DataPath%\DataGroup\Prepress" >NUL
XCOPY /Y "%XMLPath%\%XmlSubDir%\%ProductType%.pdf" "%DataPath%\DataGroup\Backup" >NUL
XCOPY /Y "%XMLPath%\%XmlSubDir%\%ProductType%.xml" "%DataPath%\DataGroup\Backup" >NUL
DEL /q "%XMLPath%\%XmlSubDir%\%ProductType%.xml"
DEL /q "%XMLPath%\%XmlSubDir%\%ProductType%Sed.xml"
DEL /q "%XMLPath%\%XmlSubDir%\%ProductType%.pdf"
DEL /q "%XMLPath%\%XmlSubDir%\%ProductType%NoCrop.pdf"
DEL /q "%XMLPath%\%XmlSubDir%\%ProductType%.ps"

%EXEPath%\XMLCreator 200 @ProcessName='%ProcessName%',@Method='SqlUpdate'
IF %ERRORLEVEL% NEQ 0 (
  :: If error generated from XMLCreator process, email notification is already sent from XMLCreator.exe so don't want to send another one. Just exit.
  ECHO ##ERROR## %ProductType%: XMLCreator failed while running ProcessDocument. No files delivered." >> "%ErrPath%\%LogErrFileName%%DateToday%.err"
)

:ExitBatch
:: Load XMLProcessDocument table to send notification of error
IF %ErrLevel% GTR 0 (
  %EXEPath%\XMLCreator 201 @ProcessName='%ProcessName%',@FileName='%ErrPath%\%LogErrFileName%%DateToday%.err'
  :: send error email
  %EXEPath%\XMLCreator 200 @ProcessName='%ProcessName%',@Method='Email'
  ECHO %TIME% %Message% >> "%ErrPath%\%LogErrFileName%%DateToday%.err"
  TYPE "%BatchPath%\%BatchSubDir%\%ErrorFileName%" >> "%ErrPath%\%LogErrFileName%%DateToday%.err"
) ELSE (
  %EXEPath%\XMLCreator 202 @ExtractID=%ExtractID%,@StartDateTime='%StartDateTime%'
)

ECHO [%TIME%] %Message% >> "%LogPath%\%LogErrFileName%%DateToday%.log"
ECHO [%DATE:~-4,4%-%DATE:~-10,2%-%DATE:~-7,2% %TIME%] ENDTIME OF %ProductType% >> "%LogPath%\%LogErrFileName%%DateToday%.log"

IF EXIST "%BatchPath%\%BatchSubDir%\%ErrorFileName%" DEL /q "%BatchPath%\%BatchSubDir%\%ErrorFileName%"
EXIT /b %ErrLevel%