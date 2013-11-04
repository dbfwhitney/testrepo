@ECHO OFF
:: Process extracts surveyDB and prepare the files for clients
SET "LogErrFileName=%1" :: SurveyDb or XmlCreatorDailyUpdate
IF [%LogErrFileName%] == [] SET "LogErrFileName=SurveyDb"

ECHO     Running child batch SurveyDb ...

CALL \\TorCwiDev01\BatchFiles\Publication\BatchInclude\MSDosServerTest.bat
SET "StartDateTime=%DateTime%"
SET "ProductType=SurveyDb"
SET "Message=%ProductType%: BUILD SUCCESSFUL"
SET /a "ErrLevel=0"
SET "ProcessName=%ProductType%"
SET "BatchSubDir=Survey"
SET "XmlSubDir=Survey"
SET "ErrorFileName=sdb.err"
SET "MaxByteSize=2000"
SET "ExtractID=100"
SET "Path2BatchMessage=See file %BatchPath%\%BatchSubDir%\%ProcessName%.bat for location of error."

ECHO ============================================================================================== >> "%LogPath%\%LogErrFileName%%DateToday%.log"
ECHO [%DATE:~-4,4%-%DATE:~-10,2%-%DATE:~-7,2% %TIME%] STARTTIME OF %ProductType% >> %LogPath%\%LogErrFileName%%DateToday%.log

IF EXIST "%BatchPath%\%BatchSubDir%\%ErrorFileName%" DEL /q "%BatchPath%\%BatchSubDir%\%ErrorFileName%"
IF EXIST "%OutputPath%\SurveyDB_*.xml" DEL /q "%OutputPath%\SurveyDB_*.xml"
IF EXIST "%OutputPath%\SurveyDb.xml" DEL /q "%OutputPath%\SurveyDb.xml"
IF EXIST %XMLPath%\%XmlSubDir%\SurveyDbPreprocess.xml DEL /q %XMLPath%\%XmlSubDir%\SurveyDbPreprocess.xml
IF EXIST %XMLPath%\%XmlSubDir%\SurveyDbOrder.xml DEL /q %XMLPath%\%XmlSubDir%\SurveyDbOrder.xml
IF EXIST %XMLPath%\%XmlSubDir%\SurveyDbSed.xml DEL /q %XMLPath%\%XmlSubDir%\SurveyDbSed.xml
IF EXIST %XMLPath%\%XmlSubDir%\SurveyDbRaw.xml DEL /q %XMLPath%\%XmlSubDir%\SurveyDbRaw.xml
IF EXIST %XMLPath%\%XmlSubDir%\SurveyDbAscii.xml DEL /q %XMLPath%\%XmlSubDir%\SurveyDbAscii.xml
IF EXIST %XMLPath%\%XmlSubDir%\survey_daily DEL /q %XMLPath%\%XmlSubDir%\survey_daily
IF EXIST %XMLPath%\%XmlSubDir%\*.swk DEL /q %XMLPath%\%XmlSubDir%\*.swk
IF EXIST %XMLPath%\%XmlSubDir%\surveydb.done DEL /q %XMLPath%\%XmlSubDir%\surveydb.done
IF EXIST %DataPath%\%XmlSubDir%\Reuters\Output\* DEL /q %DataPath%\%XmlSubDir%\Reuters\Output\*
IF EXIST %DataPath%\%XmlSubDir%\LexisNexis\Output\*.swk DEL /q %DataPath%\%XmlSubDir%\LexisNexis\Output\*.swk

%EXEPath%\XMLCreator %ExtractID%
IF %ERRORLEVEL% NEQ 0 (
:: If error generated from XMLCreator process, email notification is already sent from XMLCreator.exe so don't want to send another one. Just exit.
  SET /a "ErrLevel=0"
  SET "Message=##ERROR## %ProductType%: XMLCreator failed while generating XML file. Email notification should have been sent from XMLCreator.exe."
  GOTO ExitBatch
)

XCOPY /Y "%OutputPath%\SurveyDB_*.xml" %OutputPath%\Backup\Publication >NUL
REN "%OutputPath%\SurveyDB_*.xml" SurveyDb.xml

CALL %BatchPath%\BatchInclude\CountFilesBySize %OutputPath% SurveyDb.xml 1000 LSS >NUL
:: If the size of the output XML file is < 1000 bytes then there are no records so exit.
IF %ERRORLEVEL% EQU 1 (
  SET /a "ErrLevel=0"
  SET "Message=%Message%: No %ProductType% at this time. Output is only produced Thursdays."
  GOTO ExitBatch
) 

XCOPY /Y "%OutputPath%\SurveyDb.xml" %XMLPath%\%XmlSubDir% >NUL

java -Xms1024M -Xmx1024M -jar "c:\program files\saxon\saxon.jar" -warnings:silent -o:"%XMLPath%\%XmlSubDir%\SurveyDbPreprocess.xml" "%XMLPath%\%XmlSubDir%\SurveyDb.xml" "%XMLPath%\pre-process\wrapper_surveydb.xsl" 2>> %BatchPath%\%BatchSubDir%\%ErrorFileName%
IF %ERRORLEVEL% NEQ 0 (
  SET /a "ErrLevel+=1"
  SET "Message=1. %TIME% ##ERROR## %ProductType%: Saxon - there was a problem pre-processing the file. %Path2BatchMessage%"
  GOTO ExitBatch
)  

java -Xms1024M -Xmx1024M -jar "c:\program files\saxon\saxon.jar" -warnings:silent -o:"%XMLPath%\%XmlSubDir%\SurveyDbOrder.xml" "%XMLPath%\%XmlSubDir%\SurveyDbPreprocess.xml" "%XMLPath%\survey\surveydb\wrapper_surveydb_order.xsl" 2>> %BatchPath%\%BatchSubDir%\%ErrorFileName%
IF %ERRORLEVEL% NEQ 0 (
  SET /a "ErrLevel+=1"
  SET "Message=2. %TIME% ##ERROR## %ProductType%: Saxon - there was a problem ordering the file. %Path2BatchMessage%"
  GOTO ExitBatch
)  

"%SedExe%" -f %XMLPath%\process\surveydb_character.sed %XMLPath%\%XmlSubDir%\SurveyDbOrder.xml > %XMLPath%\%XmlSubDir%\SurveyDbSed.xml 2>> %BatchPath%\%BatchSubDir%\%ErrorFileName%
IF %ERRORLEVEL% NEQ 0 (
  SET /a "ErrLevel+=1"
  SET "Message=3. %TIME% ##ERROR## %ProductType%: Sed - there was a problem translating characters to ascii. %Path2BatchMessage%"
  GOTO ExitBatch
)  

java -Xms1024M -Xmx1024M -jar "c:\program files\saxon\saxon.jar" -warnings:silent -o:"%XMLPath%\%XmlSubDir%\SurveyDbRaw.xml" "%XMLPath%\%XmlSubDir%\SurveyDbSed.xml" "%XMLPath%\%XmlSubDir%\surveydb\wrapper_surveydb.xsl" 2>> %BatchPath%\%BatchSubDir%\%ErrorFileName%
IF %ERRORLEVEL% NEQ 0 (
  SET /a "ErrLevel+=1"
  SET "Message=4. %TIME% ##ERROR## %ProductType%: Saxon - there was a problem creating text file. %Path2BatchMessage%"
  GOTO ExitBatch
)

"%SedExe%" -f %XMLPath%\process\surveydb_character_2.sed %XMLPath%\%XmlSubDir%\SurveyDbRaw.xml > %XMLPath%\%XmlSubDir%\SurveyDbAscii.xml 2>> %BatchPath%\%BatchSubDir%\%ErrorFileName%
IF %ERRORLEVEL% NEQ 0 (
  SET /a "ErrLevel+=1"
  SET "Message=5. %TIME% ##ERROR## %ProductType%: Sed - there was with the second sed translation. %Path2BatchMessage%"
  GOTO ExitBatch
)  

java -Xms1024M -Xmx1024M -jar "c:\program files\saxon\saxon.jar" "%XMLPath%\%XmlSubDir%\SurveyDbAscii.xml" "%XMLPath%\%XmlSubDir%\surveydb\wrapper_survey_final.xsl" 2>> %BatchPath%\%BatchSubDir%\%ErrorFileName%
IF %ERRORLEVEL% NEQ 0 (
  SET /a "ErrLevel+=1"
  SET "Message=6. %TIME% ##ERROR## %ProductType%: Saxon - there was a problem creating the final files. %Path2BatchMessage%"
  GOTO ExitBatch
)  

:: 2013-10-16 - dw: This file is no longer delivered.
DEL /q %XMLPath%\%XmlSubDir%\Survey_Daily

IF EXIST %XMLPath%\%XmlSubDir%\*.swk (
  CALL %BatchPath%\BatchInclude\CountFilesBySize.bat %XMLPath%\%XmlSubDir% *.swk 0 EQU >NUL
  IF %ERRORLEVEL% NEQ 0 (
    IF %ERRORLEVEL% EQU -1 (
      SET /a "ErrLevel+=1"
      SET "Message=9. %TIME% ##ERROR## %ProductType%: File^(s^) cannot be found in specified directory. No files delivered. %Path2BatchMessage%"
      GOTO ExitBatch
    )
    :: If there are any 0 byte files then generate error and exit batch.
    IF %ERRORLEVEL% GTR 0 (
      SET /a "ErrLevel+=1"
      SET "Message=10. %TIME% ##ERROR## %ProductType%: One or more of the files tested are size of 0 byte. No files were delivered. %Path2BatchMessage%"
      GOTO ExitBatch
    )
  )
)

IF EXIST %XMLPath%\%XmlSubDir%\*.swk (
  XCOPY /Y %XMLPath%\%XmlSubDir%\*.swk %DataPath%\%XmlSubDir%\LexisNexis\Output >NUL
  XCOPY /Y %XMLPath%\%XmlSubDir%\*.swk %DataPath%\%XmlSubDir%\LexisNexis\Backup >NUL
)

IF EXIST %XMLPath%\%XmlSubDir%\surveydb.done XCOPY /Y %XMLPath%\%XmlSubDir%\surveydb.done %DataPath%\%XmlSubDir% >NUL
IF EXIST %XMLPath%\%XmlSubDir%\SurveyDb.xml DEL /q %XMLPath%\%XmlSubDir%\SurveyDb.xml
IF EXIST %XMLPath%\%XmlSubDir%\SurveyDbPreprocess.xml DEL /q %XMLPath%\%XmlSubDir%\SurveyDbPreprocess.xml
IF EXIST %XMLPath%\%XmlSubDir%\SurveyDbOrder.xml DEL /q %XMLPath%\%XmlSubDir%\SurveyDbOrder.xml
IF EXIST %XMLPath%\%XmlSubDir%\SurveyDbSed.xml DEL /q %XMLPath%\%XmlSubDir%\SurveyDbSed.xml
IF EXIST %XMLPath%\%XmlSubDir%\SurveyDbRaw.xml DEL /q %XMLPath%\%XmlSubDir%\SurveyDbRaw.xml
IF EXIST %XMLPath%\%XmlSubDir%\SurveyDbAscii.xml DEL /q %XMLPath%\%XmlSubDir%\SurveyDbAscii.xml
IF EXIST %XMLPath%\%XmlSubDir%\survey_daily DEL /q %XMLPath%\%XmlSubDir%\survey_daily
IF EXIST %XMLPath%\%XmlSubDir%\*.swk DEL /q %XMLPath%\%XmlSubDir%\*.swk
IF EXIST %XMLPath%\%XmlSubDir%\surveydb.done DEL /q %XMLPath%\%XmlSubDir%\surveydb.done

:ExitBatch
:: Load XMLProcessDocument table to send notification of error
IF %ErrLevel% GTR 0 (
  %EXEPath%\XMLCreator 201 @ProcessName='%ProcessName%',@FileName='%ErrPath%\%LogErrFileName%%DateToday%.err'
  :: send error email
  %EXEPath%\XMLCreator 200 @ProcessName='%ProcessName%',@Method='Email'
  ECHO %TIME% %Message% >> "%ErrPath%\%LogErrFileName%%DateToday%.err"
  TYPE "%BatchPath%\%BatchSubDir%\%ErrorFileName%" >> "%ErrPath%\%LogErrFileName%%DateToday%.err"
) ELSE (
  :: update XMLExtract.Failed field
  %EXEPath%\XMLCreator 202 @ExtractID=%ExtractID%,@StartDateTime='%StartDateTime%'
)

ECHO [%TIME%] %Message% >> "%LogPath%\%LogErrFileName%%DateToday%.log"
ECHO [%DATE:~-4,4%-%DATE:~-10,2%-%DATE:~-7,2% %TIME%] ENDTIME OF %ProductType% >> "%LogPath%\%LogErrFileName%%DateToday%.log"

IF EXIST "%BatchPath%\%BatchSubDir%\%ErrorFileName%" DEL /q "%BatchPath%\%BatchSubDir%\%ErrorFileName%"
EXIT /b %ErrLevel%