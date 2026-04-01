; =============================================================================
; Postilion Realtime Framework v5.6 — AutoIt GUI Installer Automation
; Standalone source file (for manual testing / non-Ansible use)
; =============================================================================
; This is the STANDALONE version with hardcoded defaults.
; For Ansible deployments, use the Jinja2 template version instead:
;   roles/postilion_realtime/templates/postilion_install.au3.j2
; =============================================================================

#include <MsgBoxConstants.au3>
#include <StringConstants.au3>

; === Configuration ===
; MODIFY THESE VALUES FOR YOUR ENVIRONMENT
Local $installDir = "C:\Postilion"
Local $dbServer = @ComputerName
Local $dbPort = "1433"
Local $dbSchema = "dbo"
Local $dbName = "realtime"
Local $dbAuth = "Windows Authentication"
Local $dbLogin = ""
Local $dbPassword = ""
Local $dbLocation = "local"
Local $dbDataDevice = "realtime_data"
Local $dbLogDevice = "realtime_log"
Local $dbDataPath = "D:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\data"
Local $dbLogPath = "D:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\data"
Local $svcHostname = @ComputerName
Local $svcDomain = @ComputerName
Local $svcUsername = "Administrator"
Local $svcPassword = "Password@123"
Local $defaultCurrency = "Naira (566)"
Local $licensePath = "C:\Postilion\realtime\license\postilion.lic"

; === Timeouts ===
Local $screenWait = 2000       ; ms between screen actions
Local $popupWait = 3           ; seconds to wait for conditional popups
Local $progressTimeout = 600   ; seconds to wait for install to complete
Local $screenTimeout = 60      ; seconds to wait for each screen

; === Logging ===
Local $logFile = "C:\logs\postilion_autoit_install.log"

; === Window titles ===
Local $mainWindow = "Realtime Install Framework"
Local $popupDirExists = "Directory Exists"
Local $popupLogonService = "Logon As Service"
Local $popupAuthError = "Authentication Error"
Local $popupEventViewer = "Event Viewer"

; === Exit codes ===
Local Const $EXIT_SUCCESS = 0
Local Const $EXIT_TIMEOUT = 1
Local Const $EXIT_UNEXPECTED = 2
Local Const $EXIT_CONTROL_NOT_FOUND = 3
Local Const $EXIT_FATAL = 99

; =============================================================================
; Logging function
; =============================================================================
Func _Log($msg)
    Local $timestamp = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC
    Local $logLine = $timestamp & " | " & $msg
    ConsoleWrite($logLine & @CRLF)
    ; Ensure log directory exists
    If Not FileExists("C:\logs") Then DirCreate("C:\logs")
    FileWriteLine($logFile, $logLine)
EndFunc

; =============================================================================
; Screen handler — waits for a screen and validates it appeared
; =============================================================================
Func _HandleScreen($screenName, $expectedText, $timeout = 0)
    If $timeout = 0 Then $timeout = $screenTimeout
    _Log("Waiting for screen: " & $screenName & " (timeout: " & $timeout & "s)")

    Local $result = WinWaitActive($mainWindow, $expectedText, $timeout)
    If $result = 0 Then
        _Log("ERROR: Timeout waiting for screen: " & $screenName)
        _Log("Expected text: " & $expectedText)
        Exit $EXIT_TIMEOUT
    EndIf

    _Log("Screen found: " & $screenName)
    Sleep($screenWait)
    Return $result
EndFunc

; =============================================================================
; Conditional popup handler
; =============================================================================
Func _HandlePopup($title, $buttonText, $waitTime = 0)
    If $waitTime = 0 Then $waitTime = $popupWait
    _Log("Checking for popup: " & $title & " (wait: " & $waitTime & "s)")

    Sleep($waitTime * 1000)
    If WinExists($title) Then
        _Log("Popup detected: " & $title)
        WinActivate($title)
        Sleep(500)

        ; Strategy 1: Exact text
        Local $clickResult = ControlClick($title, "", "[TEXT:" & $buttonText & "]")
        If $clickResult = 1 Then
            _Log("Popup button clicked via [TEXT:" & $buttonText & "]")
            Sleep(1000)
            Return True
        EndIf

        ; Strategy 2: With & accelerator (e.g. &Yes, &No, &OK)
        $clickResult = ControlClick($title, "", "[TEXT:&" & $buttonText & "]")
        If $clickResult = 1 Then
            _Log("Popup button clicked via [TEXT:&" & $buttonText & "]")
            Sleep(1000)
            Return True
        EndIf

        ; Strategy 3: CLASS:Button + text
        $clickResult = ControlClick($title, "", "[CLASS:Button; TEXT:" & $buttonText & "]")
        If $clickResult = 1 Then
            _Log("Popup button clicked via [CLASS:Button; TEXT:" & $buttonText & "]")
            Sleep(1000)
            Return True
        EndIf

        ; Strategy 4: CLASS:Button + text with &
        $clickResult = ControlClick($title, "", "[CLASS:Button; TEXT:&" & $buttonText & "]")
        If $clickResult = 1 Then
            _Log("Popup button clicked via [CLASS:Button; TEXT:&" & $buttonText & "]")
            Sleep(1000)
            Return True
        EndIf

        ; Strategy 5: Scan buttons for matching text
        For $i = 1 To 6
            Local $btnText = ControlGetText($title, "", "[CLASS:Button; INSTANCE:" & $i & "]")
            If @error Then ExitLoop
            _Log("  Popup button INSTANCE:" & $i & " text='" & $btnText & "'")
            If StringInStr($btnText, $buttonText) Then
                $clickResult = ControlClick($title, "", "[CLASS:Button; INSTANCE:" & $i & "]")
                If $clickResult = 1 Then
                    _Log("Popup button clicked via INSTANCE:" & $i)
                    Sleep(1000)
                    Return True
                EndIf
            EndIf
        Next

        ; Strategy 6: Keyboard fallback
        _Log("WARNING: All ControlClick failed on popup, trying Enter key")
        Send("{ENTER}")
        Sleep(1000)
        _Log("Popup handled via Enter key: " & $title)
        Return True
    EndIf

    _Log("Popup not detected: " & $title)
    Return False
EndFunc

; =============================================================================
; Click Next button — robust multi-strategy approach
; =============================================================================
Func _ClickNext()
    _Log("Clicking Next >")

    ; Strategy 1: Exact text match
    Local $result = ControlClick($mainWindow, "", "[TEXT:Next >]")
    If $result = 1 Then
        _Log("Next clicked via [TEXT:Next >]")
        Sleep($screenWait)
        Return
    EndIf

    ; Strategy 2: With & accelerator key
    $result = ControlClick($mainWindow, "", "[TEXT:&Next >]")
    If $result = 1 Then
        _Log("Next clicked via [TEXT:&Next >]")
        Sleep($screenWait)
        Return
    EndIf

    ; Strategy 3: Class + text
    $result = ControlClick($mainWindow, "", "[CLASS:Button; TEXT:Next >]")
    If $result = 1 Then
        _Log("Next clicked via [CLASS:Button; TEXT:Next >]")
        Sleep($screenWait)
        Return
    EndIf

    ; Strategy 4: Class + text with accelerator
    $result = ControlClick($mainWindow, "", "[CLASS:Button; TEXT:&Next >]")
    If $result = 1 Then
        _Log("Next clicked via [CLASS:Button; TEXT:&Next >]")
        Sleep($screenWait)
        Return
    EndIf

    ; Strategy 5: Scan all Button instances for one containing "Next"
    For $i = 1 To 10
        Local $btnText = ControlGetText($mainWindow, "", "[CLASS:Button; INSTANCE:" & $i & "]")
        If @error Then ExitLoop
        _Log("  Button INSTANCE:" & $i & " text='" & $btnText & "'")
        If StringInStr($btnText, "Next") Then
            $result = ControlClick($mainWindow, "", "[CLASS:Button; INSTANCE:" & $i & "]")
            If $result = 1 Then
                _Log("Next clicked via [CLASS:Button; INSTANCE:" & $i & "]")
                Sleep($screenWait)
                Return
            EndIf
        EndIf
    Next

    ; Strategy 6: Try keyboard shortcut Alt+N (common accelerator)
    _Log("WARNING: All ControlClick strategies failed, trying keyboard Alt+N")
    Send("!n")
    Sleep($screenWait)

    ; Strategy 7: Last resort — press Enter (Next is often the default/focused button)
    _Log("WARNING: Trying Enter key as last resort")
    Send("{ENTER}")
    Sleep($screenWait)

    _Log("WARNING: Next button click used keyboard fallback — verify screen advanced")
EndFunc

; =============================================================================
; Click a named button — robust multi-strategy approach
; =============================================================================
Func _ClickButton($buttonText)
    _Log("Clicking button: " & $buttonText)

    ; Strategy 1: Exact text
    Local $result = ControlClick($mainWindow, "", "[TEXT:" & $buttonText & "]")
    If $result = 1 Then
        Sleep($screenWait)
        Return True
    EndIf

    ; Strategy 2: With & accelerator (try & before first char)
    $result = ControlClick($mainWindow, "", "[TEXT:&" & $buttonText & "]")
    If $result = 1 Then
        Sleep($screenWait)
        Return True
    EndIf

    ; Strategy 3: Class + text
    $result = ControlClick($mainWindow, "", "[CLASS:Button; TEXT:" & $buttonText & "]")
    If $result = 1 Then
        Sleep($screenWait)
        Return True
    EndIf

    ; Strategy 4: Scan all buttons
    For $i = 1 To 10
        Local $btnText = ControlGetText($mainWindow, "", "[CLASS:Button; INSTANCE:" & $i & "]")
        If @error Then ExitLoop
        If StringInStr($btnText, $buttonText) Then
            $result = ControlClick($mainWindow, "", "[CLASS:Button; INSTANCE:" & $i & "]")
            If $result = 1 Then
                _Log("Button '" & $buttonText & "' clicked via INSTANCE:" & $i)
                Sleep($screenWait)
                Return True
            EndIf
        EndIf
    Next

    _Log("WARNING: Could not click button: " & $buttonText)
    Return False
EndFunc

; =============================================================================
; Dump all visible controls in the window (diagnostic)
; =============================================================================
Func _DumpControls()
    _Log("--- Control dump for window: " & $mainWindow & " ---")
    ; Dump Button controls
    For $i = 1 To 15
        Local $text = ControlGetText($mainWindow, "", "[CLASS:Button; INSTANCE:" & $i & "]")
        If @error Then ExitLoop
        Local $handle = ControlGetHandle($mainWindow, "", "[CLASS:Button; INSTANCE:" & $i & "]")
        _Log("  Button INSTANCE:" & $i & " text='" & $text & "' handle=" & $handle)
    Next
    ; Dump Edit controls — extended to 25 to catch all screens' fields
    For $i = 1 To 25
        Local $text2 = ControlGetText($mainWindow, "", "[CLASS:Edit; INSTANCE:" & $i & "]")
        If @error Then ExitLoop
        _Log("  Edit INSTANCE:" & $i & " text='" & $text2 & "'")
    Next
    ; Dump ComboBox controls
    For $i = 1 To 5
        Local $text3 = ControlGetText($mainWindow, "", "[CLASS:ComboBox; INSTANCE:" & $i & "]")
        If @error Then ExitLoop
        _Log("  ComboBox INSTANCE:" & $i & " text='" & $text3 & "'")
    Next
    ; Dump Static/Label controls
    For $i = 1 To 10
        Local $text4 = ControlGetText($mainWindow, "", "[CLASS:Static; INSTANCE:" & $i & "]")
        If @error Then ExitLoop
        _Log("  Static INSTANCE:" & $i & " text='" & StringLeft($text4, 80) & "'")
    Next
    _Log("--- End control dump ---")
EndFunc

; =============================================================================
; Count total visible Edit controls in the main window.
; Returns the highest INSTANCE number that responds without error.
; =============================================================================
Func _CountEdits()
    Local $count = 0
    For $i = 1 To 30
        ControlGetText($mainWindow, "", "[CLASS:Edit; INSTANCE:" & $i & "]")
        If @error Then ExitLoop
        $count = $i
    Next
    Return $count
EndFunc

; =============================================================================
; Find Edit controls that belong to the CURRENT screen page.
; The wizard retains all previous screens' Edit controls in memory.
; This function finds Edit instances above a given starting index.
; =============================================================================
Func _FindEditInstance($startFrom, $expectedValue)
    ; Search for an Edit field containing the expected value (or empty for password)
    For $i = $startFrom To 30
        Local $text = ControlGetText($mainWindow, "", "[CLASS:Edit; INSTANCE:" & $i & "]")
        If @error Then ExitLoop
        If $expectedValue = "" And StringLen($text) = 0 Then
            _Log("  Found empty Edit at INSTANCE:" & $i)
            Return $i
        ElseIf StringInStr($text, $expectedValue) Then
            _Log("  Found Edit with '" & $expectedValue & "' at INSTANCE:" & $i)
            Return $i
        EndIf
    Next
    Return 0
EndFunc

; =============================================================================
; Set a field value using Tab navigation from the active control.
; More reliable than INSTANCE numbers since the wizard reuses Edit controls.
; =============================================================================
Func _TabSetField($value, $fieldName, $useRawSend = False)
    _Log("  Tab-setting field '" & $fieldName & "' to: " & $value)
    Send("^a")       ; Select all existing text
    Sleep(50)
    If $useRawSend Then
        Send($value, 1)  ; flag=1 = raw chars, no special key interpretation
    Else
        Send($value)
    EndIf
    Sleep(200)
    _Log("  Field '" & $fieldName & "' typed OK")
EndFunc

Func _TabNext()
    Send("{TAB}")
    Sleep(200)
EndFunc

; =============================================================================
; MAIN INSTALLATION FLOW
; =============================================================================

_Log("=== Postilion Realtime Framework AutoIt Installer (Standalone) ===")
_Log("Install directory: " & $installDir)
_Log("DB Server: " & $dbServer)
_Log("Service hostname: " & $svcHostname)
_Log("Starting GUI automation...")

; Ensure AutoIt options are set for reliability
AutoItSetOption("WinTitleMatchMode", 2)   ; substring match
AutoItSetOption("SendKeyDelay", 50)
AutoItSetOption("WinWaitDelay", 250)

; =========================================================================
; Screen 1: Welcome
; =========================================================================
_HandleScreen("Screen 1: Welcome", "Welcome to the Installation Wizard")
_Log("Dumping controls on Screen 1 for diagnostics...")
_DumpControls()
_ClickNext()

; =========================================================================
; Screen 2: Destination Directory
; =========================================================================
_HandleScreen("Screen 2: Destination Directory", "Destination Directory")

_Log("Setting destination directory to: " & $installDir)
Local $editResult = ControlSetText($mainWindow, "Destination Directory", "[CLASS:Edit; INSTANCE:1]", $installDir)
If $editResult = 0 Then
    _Log("ERROR: Cannot set destination directory in edit field")
    Exit $EXIT_CONTROL_NOT_FOUND
EndIf
Sleep(500)
_ClickNext()

; =========================================================================
; Screen 2a: Directory Exists (CONDITIONAL)
; =========================================================================
_HandlePopup($popupDirExists, "Yes", $popupWait)

; =========================================================================
; Screen 3: Installation Type
; =========================================================================
_HandleScreen("Screen 3: Installation Type", "Installation Type")

_Log("Verifying Principal Server is selected")
ControlClick($mainWindow, "Installation Type", "[TEXT:Principal Server]")
Sleep(500)
_ClickNext()

; =========================================================================
; Screen 4: License Validation
; =========================================================================
_HandleScreen("Screen 4: License Validation", "License Validation")

_Log("License path: " & $licensePath)
ControlSetText($mainWindow, "License Validation", "[CLASS:Edit; INSTANCE:1]", $licensePath)
Sleep(500)
_ClickNext()

; =========================================================================
; Screen 5: Realtime Framework Data Source
; =========================================================================
_HandleScreen("Screen 5: Data Source", "Realtime Framework Data Source")

; Dump controls to verify Edit INSTANCE mapping
_Log("Dumping controls on Screen 5 for diagnostics...")
_DumpControls()

; From the control dump, the DB fields on Screen 5 are at INSTANCE:6-9
; (INSTANCE:1-5 are from previous screens: license path, disk info, etc.)
; Verified from actual dump data:
;   INSTANCE:6 = DB Server (pre-filled with computer name)
;   INSTANCE:7 = Port (pre-filled 1433)
;   INSTANCE:8 = Schema (pre-filled dbo)
;   INSTANCE:9 = DB Name (pre-filled realtime)
;   INSTANCE:10 = SQL login (empty)

_Log("[Screen 5] Setting DB Server (INSTANCE:6): " & $dbServer)
ControlSetText($mainWindow, "", "[CLASS:Edit; INSTANCE:6]", $dbServer)
Sleep(300)

_Log("[Screen 5] Setting DB Port (INSTANCE:7): " & $dbPort)
ControlSetText($mainWindow, "", "[CLASS:Edit; INSTANCE:7]", $dbPort)
Sleep(300)

_Log("[Screen 5] Setting DB Schema (INSTANCE:8): " & $dbSchema)
ControlSetText($mainWindow, "", "[CLASS:Edit; INSTANCE:8]", $dbSchema)
Sleep(300)

_Log("[Screen 5] Setting DB Name (INSTANCE:9): " & $dbName)
ControlSetText($mainWindow, "", "[CLASS:Edit; INSTANCE:9]", $dbName)
Sleep(300)

; Verify Screen 5 writes
Local $vS5_1 = ControlGetText($mainWindow, "", "[CLASS:Edit; INSTANCE:6]")
Local $vS5_2 = ControlGetText($mainWindow, "", "[CLASS:Edit; INSTANCE:7]")
Local $vS5_3 = ControlGetText($mainWindow, "", "[CLASS:Edit; INSTANCE:8]")
Local $vS5_4 = ControlGetText($mainWindow, "", "[CLASS:Edit; INSTANCE:9]")
_Log("[Screen 5] Verify: Server='" & $vS5_1 & "' Port='" & $vS5_2 & "' Schema='" & $vS5_3 & "' DBName='" & $vS5_4 & "'")

_Log("[Screen 5] Setting DB Auth: " & $dbAuth)
ControlCommand($mainWindow, "", "[CLASS:ComboBox; INSTANCE:2]", "SelectString", $dbAuth)
Sleep(500)

If $dbAuth = "SQL Server Authentication" Then
    _Log("[Screen 5] Setting SQL Auth credentials")
    ControlSetText($mainWindow, "", "[CLASS:Edit; INSTANCE:10]", $dbLogin)
    Sleep(300)
    ; SQL password field may be INSTANCE:11 when visible
    ControlSetText($mainWindow, "", "[CLASS:Edit; INSTANCE:11]", $dbPassword)
    Sleep(300)
EndIf

_ClickNext()

; =========================================================================
; Screen 6: Realtime Framework Database
; =========================================================================
_HandleScreen("Screen 6: Database Details", "Realtime Framework Database")

; Dump controls for diagnostics
_Log("Dumping controls on Screen 6 for diagnostics...")
_DumpControls()

; Count total Edit controls to find where Screen 6's fields start
Local $editCountS6 = _CountEdits()
_Log("[Screen 6] Total Edit controls: " & $editCountS6)

; CRITICAL: The LAST Edit control on every screen is a read-only description
; text (e.g. "Provide the details of the Realtime Framework database.").
; The actual 5 data fields are BEFORE that description Edit.
; So fields are at maxEdit-5 through maxEdit-1 (NOT maxEdit-4 through maxEdit).
Local $dbNameInst6 = $editCountS6 - 5
Local $dataDevInst = $editCountS6 - 4
Local $dataPathInst = $editCountS6 - 3
Local $logDevInst = $editCountS6 - 2
Local $logPathInst = $editCountS6 - 1

_Log("[Screen 6] Calculated field instances: DBName=" & $dbNameInst6 & " DataDev=" & $dataDevInst & " DataPath=" & $dataPathInst & " LogDev=" & $logDevInst & " LogPath=" & $logPathInst)

If $dbLocation = "local" Then
    _Log("[Screen 6] Selecting Local database server")
    ControlClick($mainWindow, "", "[TEXT:Local database server]")
Else
    _Log("[Screen 6] Selecting Remote database server")
    ControlClick($mainWindow, "", "[TEXT:Remote database server]")
EndIf
Sleep(500)

_Log("[Screen 6] Setting Database Name (INSTANCE:" & $dbNameInst6 & "): " & $dbName)
ControlSetText($mainWindow, "", "[CLASS:Edit; INSTANCE:" & $dbNameInst6 & "]", $dbName)
Sleep(300)

_Log("[Screen 6] Setting Data Device (INSTANCE:" & $dataDevInst & "): " & $dbDataDevice)
ControlSetText($mainWindow, "", "[CLASS:Edit; INSTANCE:" & $dataDevInst & "]", $dbDataDevice)
Sleep(300)

Local $dataFilePath = $dbDataPath & "\" & $dbDataDevice & ".mdf"
_Log("[Screen 6] Setting Data File Path (INSTANCE:" & $dataPathInst & "): " & $dataFilePath)
ControlSetText($mainWindow, "", "[CLASS:Edit; INSTANCE:" & $dataPathInst & "]", $dataFilePath)
Sleep(300)

_Log("[Screen 6] Setting Log Device (INSTANCE:" & $logDevInst & "): " & $dbLogDevice)
ControlSetText($mainWindow, "", "[CLASS:Edit; INSTANCE:" & $logDevInst & "]", $dbLogDevice)
Sleep(300)

Local $logFilePath = $dbLogPath & "\" & $dbLogDevice & ".ldf"
_Log("[Screen 6] Setting Log File Path (INSTANCE:" & $logPathInst & "): " & $logFilePath)
ControlSetText($mainWindow, "", "[CLASS:Edit; INSTANCE:" & $logPathInst & "]", $logFilePath)
Sleep(300)

_ClickNext()

; =========================================================================
; Screen 7: Services Server
; =========================================================================
_HandleScreen("Screen 7: Services Server", "Services Server")

; Dump controls for diagnostics
_Log("Dumping controls on Screen 7 for diagnostics...")
_DumpControls()

; Count total Edit controls — the LAST Edit is a description text,
; so the hostname field is at maxEdit - 1 (second to last).
Local $editCountS7 = _CountEdits()
Local $hostnameInst = $editCountS7 - 1
_Log("[Screen 7] Total Edit controls: " & $editCountS7 & " — hostname is at INSTANCE:" & $hostnameInst)

_Log("[Screen 7] Setting Services Server hostname (INSTANCE:" & $hostnameInst & "): " & $svcHostname)
ControlSetText($mainWindow, "", "[CLASS:Edit; INSTANCE:" & $hostnameInst & "]", $svcHostname)
Sleep(500)

; Verify write
Local $verifyHost = ControlGetText($mainWindow, "", "[CLASS:Edit; INSTANCE:" & $hostnameInst & "]")
_Log("[Screen 7] Hostname verify: '" & $verifyHost & "'")

_ClickNext()

; =========================================================================
; Screen 8: Service Account
; =========================================================================
_HandleScreen("Screen 8: Service Account", "Service Account")

; Dump controls to verify field mapping (extended to INSTANCE:25)
_Log("Dumping controls on Screen 8 for diagnostics...")
_DumpControls()

; =========================================================================
; CRITICAL: The wizard keeps ALL Edit controls from ALL previous screens.
; Edit INSTANCE:1-10+ are from Screens 2-7. Screen 8's Domain/Username/
; Password fields are at higher INSTANCE numbers (11+).
; We dynamically find the total Edit count and use the last 3.
; =========================================================================

_Log("[Screen 8] Values: Domain='" & $svcDomain & "' Username='" & $svcUsername & "' Password='" & $svcPassword & "'")

; Make sure the main window is active and focused
WinActivate($mainWindow)
Sleep(500)

; Find the highest Edit INSTANCE that exists
Local $maxEdit = _CountEdits()
_Log("[Screen 8] Total Edit controls found: " & $maxEdit)

; Screen 8 adds 3 fields (Domain, Username, Password) before the
; description text Edit. So they are at maxEdit-3, maxEdit-2, maxEdit-1.
Local $domainInstance = $maxEdit - 3
Local $usernameInstance = $maxEdit - 2
Local $passwordInstance = $maxEdit - 1

_Log("[Screen 8] Calculated field instances: Domain=" & $domainInstance & " Username=" & $usernameInstance & " Password=" & $passwordInstance)

; Read current values before setting
Local $preDomain = ControlGetText($mainWindow, "", "[CLASS:Edit; INSTANCE:" & $domainInstance & "]")
Local $preUser = ControlGetText($mainWindow, "", "[CLASS:Edit; INSTANCE:" & $usernameInstance & "]")
Local $prePw = ControlGetText($mainWindow, "", "[CLASS:Edit; INSTANCE:" & $passwordInstance & "]")
_Log("[Screen 8] Pre-set values: Domain='" & $preDomain & "' Username='" & $preUser & "' Password='" & $prePw & "' (pw length=" & StringLen($prePw) & ")")

; --- Set Domain ---
_Log("[Screen 8] Setting Domain (INSTANCE:" & $domainInstance & ") to: " & $svcDomain)
ControlSetText($mainWindow, "", "[CLASS:Edit; INSTANCE:" & $domainInstance & "]", $svcDomain)
Sleep(300)

; --- Set Username ---
_Log("[Screen 8] Setting Username (INSTANCE:" & $usernameInstance & ") to: " & $svcUsername)
ControlSetText($mainWindow, "", "[CLASS:Edit; INSTANCE:" & $usernameInstance & "]", $svcUsername)
Sleep(300)

; --- Set Password (try ControlSetText first, then Send fallback) ---
_Log("[Screen 8] Setting Password (INSTANCE:" & $passwordInstance & ") to: " & $svcPassword)
Local $pwResult = ControlSetText($mainWindow, "", "[CLASS:Edit; INSTANCE:" & $passwordInstance & "]", $svcPassword)
_Log("[Screen 8] ControlSetText Password result: " & $pwResult)
Sleep(300)

; Read back to verify
Local $verifyPw = ControlGetText($mainWindow, "", "[CLASS:Edit; INSTANCE:" & $passwordInstance & "]")
_Log("[Screen 8] Password read-back: '" & $verifyPw & "' (length=" & StringLen($verifyPw) & ")")

; If password is empty, fall back to ControlFocus + Send
If StringLen($verifyPw) = 0 Then
    _Log("[Screen 8] Password empty after ControlSetText — trying ControlFocus + Send")
    ControlFocus($mainWindow, "", "[CLASS:Edit; INSTANCE:" & $passwordInstance & "]")
    Sleep(200)
    Send("^a")
    Sleep(50)
    Send("{DELETE}")
    Sleep(50)
    Send($svcPassword, 1)
    Sleep(500)
    $verifyPw = ControlGetText($mainWindow, "", "[CLASS:Edit; INSTANCE:" & $passwordInstance & "]")
    _Log("[Screen 8] Password after Send: '" & $verifyPw & "' (length=" & StringLen($verifyPw) & ")")
EndIf

; If still empty, try ControlSend
If StringLen($verifyPw) = 0 Then
    _Log("[Screen 8] Password still empty — trying ControlSend")
    ControlSend($mainWindow, "", "[CLASS:Edit; INSTANCE:" & $passwordInstance & "]", $svcPassword, 1)
    Sleep(500)
    $verifyPw = ControlGetText($mainWindow, "", "[CLASS:Edit; INSTANCE:" & $passwordInstance & "]")
    _Log("[Screen 8] Password after ControlSend: '" & $verifyPw & "' (length=" & StringLen($verifyPw) & ")")
EndIf

; --- Final verification ---
Local $finalDomain = ControlGetText($mainWindow, "", "[CLASS:Edit; INSTANCE:" & $domainInstance & "]")
Local $finalUser = ControlGetText($mainWindow, "", "[CLASS:Edit; INSTANCE:" & $usernameInstance & "]")
Local $finalPw = ControlGetText($mainWindow, "", "[CLASS:Edit; INSTANCE:" & $passwordInstance & "]")
_Log("[Screen 8] FINAL VERIFY — Domain='" & $finalDomain & "' Username='" & $finalUser & "' Password='" & $finalPw & "' (pw length=" & StringLen($finalPw) & ")")

_ClickNext()

; =========================================================================
; Screen 8a: Logon As Service (CONDITIONAL)
; =========================================================================
_HandlePopup($popupLogonService, "Yes", $popupWait)

; =========================================================================
; Screen 8b: Authentication Error (CONDITIONAL)
; The installer may show this if the service account cannot "log on as a
; service". Click Yes to ignore and continue.
; =========================================================================
_HandlePopup($popupAuthError, "Yes", $popupWait)

; =========================================================================
; Screen 9: Default Currency
; =========================================================================
_HandleScreen("Screen 9: Default Currency", "Default Currency")

; Dump controls for diagnostics
_Log("Dumping controls on Screen 9 for diagnostics...")
_DumpControls()

; The currency ComboBox is NOT at INSTANCE:1 — that's the SQL Server platform
; combo from Screen 5. Find the last ComboBox which is Screen 9's currency.
Local $maxCombo = 0
For $i = 1 To 10
    ControlGetText($mainWindow, "", "[CLASS:ComboBox; INSTANCE:" & $i & "]")
    If @error Then ExitLoop
    $maxCombo = $i
Next
_Log("[Screen 9] Total ComboBox controls: " & $maxCombo & " — currency is at INSTANCE:" & $maxCombo)

; Log current selection before changing
Local $currentCurrency = ControlGetText($mainWindow, "", "[CLASS:ComboBox; INSTANCE:" & $maxCombo & "]")
_Log("[Screen 9] Current currency selection: '" & $currentCurrency & "'")

; Log all available items in the ComboBox for diagnostics
Local $itemCount = ControlCommand($mainWindow, "", "[CLASS:ComboBox; INSTANCE:" & $maxCombo & "]", "GetCount", "")
_Log("[Screen 9] ComboBox item count: " & $itemCount)

_Log("[Screen 9] Selecting default currency: " & $defaultCurrency)

; Strategy 1: Try SelectString (prefix match)
Local $currencyResult = ControlCommand($mainWindow, "", "[CLASS:ComboBox; INSTANCE:" & $maxCombo & "]", "SelectString", $defaultCurrency)
Sleep(300)
Local $afterSelect = ControlGetText($mainWindow, "", "[CLASS:ComboBox; INSTANCE:" & $maxCombo & "]")
_Log("[Screen 9] After SelectString: result=" & $currencyResult & " current='" & $afterSelect & "'")

; Strategy 2: If SelectString didn't pick the right one, search all items
If StringInStr($afterSelect, "Naira") = 0 Then
    _Log("[Screen 9] SelectString didn't match Naira — scanning all items...")
    For $idx = 0 To $itemCount - 1
        ControlCommand($mainWindow, "", "[CLASS:ComboBox; INSTANCE:" & $maxCombo & "]", "SetCurrentSelection", $idx)
        Sleep(50)
        Local $itemText = ControlGetText($mainWindow, "", "[CLASS:ComboBox; INSTANCE:" & $maxCombo & "]")
        If StringInStr($itemText, "Naira") Then
            _Log("[Screen 9] Found Naira at index " & $idx & ": '" & $itemText & "'")
            ExitLoop
        EndIf
    Next
    Local $finalCurrency = ControlGetText($mainWindow, "", "[CLASS:ComboBox; INSTANCE:" & $maxCombo & "]")
    _Log("[Screen 9] Final currency: '" & $finalCurrency & "'")
EndIf
Sleep(500)
_ClickNext()

; =========================================================================
; Screen 10: Ready to Install
; =========================================================================
_HandleScreen("Screen 10: Ready to Install", "Ready to Install")
_Log("Starting installation...")
_ClickNext()

; =========================================================================
; Screen 10a: Event Viewer Warning (CONDITIONAL)
; =========================================================================
_HandlePopup($popupEventViewer, "OK", $popupWait)

; =========================================================================
; Screen 11: Install in Progress — WAIT
; =========================================================================
_Log("Installation in progress — waiting up to " & $progressTimeout & " seconds...")

WinWaitActive($mainWindow, "Install in progress", 30)

Local $installComplete = WinWaitActive($mainWindow, "PCI DSS", $progressTimeout)
If $installComplete = 0 Then
    _Log("ERROR: Installation timed out after " & $progressTimeout & " seconds")
    _Log("The installer may still be running. Check the server manually.")
    Exit $EXIT_TIMEOUT
EndIf

_Log("Installation completed — PCI DSS screen appeared")

; =========================================================================
; Screen 12: PCI DSS Considerations
; =========================================================================
_Log("Screen 12: PCI DSS Considerations")
Sleep($screenWait)
_ClickNext()

; =========================================================================
; Screen 13: Installation Complete
; =========================================================================
_HandleScreen("Screen 13: Installation Complete", "Installation Complete")

_Log("Clicking Finish")
If Not _ClickButton("Finish") Then
    _Log("WARNING: Finish button click failed, trying Enter key")
    Send("{ENTER}")
EndIf
Sleep(2000)

; =========================================================================
; DONE
; =========================================================================
_Log("=== Installation completed successfully ===")
_Log("Exit code: 0")
Exit $EXIT_SUCCESS
