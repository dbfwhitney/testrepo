@ECHO OFF
:: call MSDOSServerTest.bat to determine server name and set up dir paths
CALL \\TorCwiDev01\BatchFiles\Publication\BatchInclude\MSDosServerTest.bat

SET "StartDateTime=%DateTime%"
SET "ProductType=XMLFragment Drop Temp Table"
SET "Message=%ProductType%: BUILD SUCCESSFUL"
SET /a "ErrLevel=0"

ECHO ==============================================================================================
ECHO [%DATE:~-4,4%-%DATE:~-10,2%-%DATE:~-7,2% %TIME%] STARTTIME OF %ProductType%

%EXEPath%\XMLCreator 77
IF %ERRORLEVEL% NEQ 0 (
  :: If error generated from XMLCreator process, email notification is already sent from XMLCreator.exe so don't want to send another one. Just exit.
  SET /a "ErrLevel=0"
  SET "Message=##ERROR## Survey Lookup: XMLCreator failed while generating XML file. Email notification should have been sent from XMLCreator.exe."
  GOTO ExitBatch
) ELSE (
  ECHO [%TIME%] %Message%
)

:ExitBatch
ECHO [%DATE:~-4,4%-%DATE:~-10,2%-%DATE:~-7,2% %TIME%] ENDTIME OF %ProductType%
EXIT /b %ErrLevel%