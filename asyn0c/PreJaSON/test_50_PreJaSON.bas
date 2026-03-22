Attribute VB_Name = "test_50_PreJaSON"
Sub TestPreJaSON()
    Dim p As New PreJaSON
    Dim d As Object
    Set d = CreateObject("Scripting.Dictionary")
    
    ' Build the data structure
    d.Add "system", "Lazarus"
    d.Add "ide_ready", True
    d.Add "error_log", Null
    
    Dim config As Object
    Set config = CreateObject("Scripting.Dictionary")
    config.Add "host", "127.0.0.1"
    config.Add "port", 8080
    d.Add "config", config
    
    Dim params As New Collection
    params.Add 1
    params.Add 1.5
    params.Add 2025
    d.Add "parameters", params
    
    ' Encode
    Dim encoded As String
    encoded = p.Encode(d)
    
    ' Write to file to see the real glyphs
    WriteFileUTF8 "C:\Users\Public\PreJaSON_Output.txt", encoded
    
    ' Decode
    ' ...    Dim result As Object
    Set result = p.Decode(encoded)
    Debug.Print "--- Decoded Check ---"
    Debug.Print "System: " & result("system")
    Debug.Print "Port: " & result("config")("port")
    Debug.Print "Param 3: " & result("parameters")(3)
End Sub

Sub WriteFileUTF8(filePath As String, textContent As String)
    Dim stream As Object
    Set stream = CreateObject("ADODB.Stream")
    stream.Type = 2 ' adTypeText
    stream.Charset = "utf-8"
    stream.Open
    stream.WriteText textContent
    stream.SaveToFile filePath, 2 ' adSaveCreateOverWrite
    stream.Close
End Sub
