VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "PreJaSON"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
' ========================================================================================
' PreJaSON (Prejudice-JSON) Codec for VBA v7.1
' Implements the Predicate Logic / Lojbanic Grammar defined by Structural Recursion.
'
' Usage:
'   Dim p as New PreJaSON
'   Dim json as String
'   json = p.Encode(myDict)
'   Set myDict = p.Decode(json)
'
' Data Mapping:
'   P-JSON Object ⟦...⟧  <--> Scripting.Dictionary
'   P-JSON Array  ⟨...⟩  <--> VBA Collection
'   P-JSON String ⌜...⌝  <--> String
'   go'i / nago'i        <--> Boolean
'   noda                 <--> Null
' ========================================================================================

Option Explicit

' --- Lojban Atoms ---
Private Const ATOM_TRUE As String = "go'i"
Private Const ATOM_FALSE As String = "nago'i"
Private Const ATOM_NULL As String = "noda"

' --- Escape Control Characters (Module-level variables) ---
Private m_breakSUB As Byte   ' 0x1A - ASCII SUB: next char is literal
Private m_breakESC As Byte   ' 0x1B - ASCII ESC: next char literal after subtracting 0x40

' --- Parsing State ---
Private m_Tokens As Collection
Private m_Cursor As Long

' ========================================================================================
'  PROPERTIES (Unicode Glyphs)
'  (These must come AFTER the declarations above)
' ========================================================================================

' --- Structural Glyphs (Unicode) ---
Private Property Get G_OBJ_START() As String: G_OBJ_START = ChrW(&H27E6): End Property ' ⟦
Private Property Get G_OBJ_END() As String:   G_OBJ_END = ChrW(&H27E7):   End Property ' ⟧
Private Property Get G_ARR_START() As String: G_ARR_START = ChrW(&H27E8): End Property ' ⟨
Private Property Get G_ARR_END() As String:   G_ARR_END = ChrW(&H27E9):   End Property ' ⟩
Private Property Get G_AND() As String:       G_AND = ChrW(&H2227):       End Property ' ∧
Private Property Get G_MAP() As String:       G_MAP = ChrW(&H21A6):       End Property ' ↦
Private Property Get G_BULLET() As String:    G_BULLET = ChrW(&H2022):    End Property ' •
Private Property Get G_STR_START() As String: G_STR_START = ChrW(&H231C): End Property ' ⌜
Private Property Get G_STR_END() As String:   G_STR_END = ChrW(&H231D):   End Property ' ⌝

' ========================================================================================
'  PUBLIC METHODS
' ========================================================================================

' Encodes a VBA Variant (Dictionary, Collection, Array, String, Number, Bool, Null) to PreJaSON
Public Function Encode(ByVal val As Variant) As String
    Dim vType As Integer
    vType = VarType(val)
    
    ' Atomic: Null
    If IsNull(val) Then
        Encode = ATOM_NULL
        Exit Function
    End If
    
    ' Atomic: Boolean
    If vType = vbBoolean Then
        If val Then Encode = ATOM_TRUE Else Encode = ATOM_FALSE
        Exit Function
    End If
    
    ' Atomic: String
    If vType = vbString Then
        Dim escapedStr As String
        escapedStr = EscapeString(val)
        Encode = G_STR_START & escapedStr & G_STR_END
        Exit Function
    End If
    
    ' Atomic: Numbers (Integer, Long, Single, Double, Currency, Decimal, Byte)
    Select Case vType
        Case vbInteger, vbLong, vbSingle, vbDouble, vbCurrency, vbDecimal, vbByte
            Encode = CStr(val)
            Exit Function
    End Select
    
    ' Complex: Objects (Dictionaries) and Arrays (Collections/Arrays)
    If IsObject(val) Then
        If TypeName(val) = "Dictionary" Then
            Encode = EncodeDictionary(val)
            Exit Function
        ElseIf TypeName(val) = "Collection" Then
            Encode = EncodeCollection(val)
            Exit Function
        End If
    ElseIf IsArray(val) Then
        Encode = EncodeArray(val)
        Exit Function
    End If
    
    Err.Raise 5, "PreJaSON", "Unsupported type for encoding: " & TypeName(val)
End Function

' Initializes escape control characters (call before Encode/Decode if using non-default values)
Public Sub InitializeEscapeChars(Optional subChar As Byte = &H1A, Optional escChar As Byte = &H1B)
    m_breakSUB = subChar
    m_breakESC = escChar
End Sub

' Decodes a PreJaSON string into VBA types (Dictionary, Collection, Variant)
Public Function Decode(ByVal strInput As String) As Variant
    ' Initialize escape chars if not already set
    If m_breakSUB = 0 Then m_breakSUB = &H1A
    If m_breakESC = 0 Then m_breakESC = &H1B
    
    Set m_Tokens = Tokenize(strInput)
    m_Cursor = 1
    
    If m_Tokens.Count = 0 Then
        Decode = Empty
        Exit Function
    End If
    
    AssignVariant Decode, Parse()
End Function

' ========================================================================================
' INTERNAL ENCODERS
' Fix: Arguments changed to ByVal to accept Variants containing these objects.
' ========================================================================================

Private Function EncodeCollection(ByVal c As Collection) As String
    If c.Count = 0 Then
        EncodeCollection = G_ARR_START & G_ARR_END
        Exit Function
    End If
    
    Dim s As String, i As Long
    s = G_ARR_START & " "
    For i = 1 To c.Count
        s = s & Encode(c(i))
        If i < c.Count Then s = s & " " & G_AND & " "
    Next i
    s = s & " " & G_ARR_END
    EncodeCollection = s
End Function

Private Function EncodeArray(ByVal arr As Variant) As String
    Dim lb As Long, ub As Long, i As Long
    lb = LBound(arr): ub = UBound(arr)
    
    If ub < lb Then
        EncodeArray = G_ARR_START & G_ARR_END
        Exit Function
    End If
    
    Dim s As String
    s = G_ARR_START & " "
    For i = lb To ub
        s = s & Encode(arr(i))
        If i < ub Then s = s & " " & G_AND & " "
    Next i
    s = s & " " & G_ARR_END
    EncodeArray = s
End Function

Private Function EncodeDictionary(ByVal d As Object) As String
    If d.Count = 0 Then
        EncodeDictionary = G_OBJ_START & G_OBJ_END
        Exit Function
    End If
    
    Dim s As String, k As Variant, keys As Variant, i As Long
    keys = d.keys
    s = G_OBJ_START & " "
    
    For i = LBound(keys) To UBound(keys)
        k = keys(i)
        Dim escapedKey As String
        escapedKey = EscapeString(k)
        ' Pair: •⌜key⌝ ↦ value
        s = s & G_BULLET & G_STR_START & escapedKey & G_STR_END & " " & G_MAP & " " & Encode(d(k))
        If i < UBound(keys) Then s = s & " " & G_AND & " "
    Next i
    
    s = s & " " & G_OBJ_END
    EncodeDictionary = s
End Function

' ========================================================================================
' PARSER & TOKENIZER
' ========================================================================================

' Parses the current token stream recursively
Private Function Parse() As Variant
    Dim tok As Object
    Set tok = Peek()
    
    ' Atomic types
    If tok("type") = "STRING" Then
        Parse = Consume("STRING")("value")
        Exit Function
    ElseIf tok("type") = "NUMBER" Then
        Parse = Consume("NUMBER")("value")
        Exit Function
    ElseIf tok("type") = "BOOL" Then
        Parse = Consume("BOOL")("value")
        Exit Function
    ElseIf tok("type") = "NULL" Then
        Consume "NULL"
        Parse = Null
        Exit Function
    End If
    
    ' Array ⟨ ... ⟩
    If tok("type") = "GLYPH" And tok("value") = G_ARR_START Then
        Set Parse = ParseArray()
        Exit Function
    End If
    
    ' Object ⟦ ... ⟧
    If tok("type") = "GLYPH" And tok("value") = G_OBJ_START Then
        Set Parse = ParseObject()
        Exit Function
    End If
    
    ' Escaped characters (should not appear at top level in well-formed P-JSON)
    If tok("type") = "ESCAPED_CHAR" Then
        Parse = Consume("ESCAPED_CHAR")("value")
        Exit Function
    End If
    
    Err.Raise 5000, "PreJaSON", "Unexpected token: " & tok("value")
End Function

Private Function ParseArray() As Collection
    Dim res As New Collection
    Consume "GLYPH", G_ARR_START
    
    Dim tok As Object
    Set tok = Peek()
    
    ' Empty array check
    If Not tok Is Nothing Then
        If tok("type") = "GLYPH" And tok("value") = G_ARR_END Then
            Consume "GLYPH", G_ARR_END
            Set ParseArray = res
            Exit Function
        End If
    End If
    
    Do
        res.Add Parse()
        Set tok = Peek()
        
        If tok Is Nothing Then Err.Raise 5001, "PreJaSON", "Unterminated Array"
        
        If tok("type") = "GLYPH" And tok("value") = G_AND Then
            Consume "GLYPH", G_AND ' Consume separator
        ElseIf tok("type") = "GLYPH" And tok("value") = G_ARR_END Then
            Consume "GLYPH", G_ARR_END
            Exit Do
        Else
            Err.Raise 5002, "PreJaSON", "Expected ∧ or ⟩, got " & tok("value")
        End If
    Loop
    Set ParseArray = res
End Function

Private Function ParseObject() As Object
    ' Uses Late Binding for Dictionary to avoid Reference requirements
    Dim res As Object
    Set res = CreateObject("Scripting.Dictionary")
    
    Consume "GLYPH", G_OBJ_START
    
    Dim tok As Object
    Set tok = Peek()
    
    ' Empty object check
    If Not tok Is Nothing Then
        If tok("type") = "GLYPH" And tok("value") = G_OBJ_END Then
            Consume "GLYPH", G_OBJ_END
            Set ParseObject = res
            Exit Function
        End If
    End If
    
    Do
        ' Expect Pair: •⌜key⌝ ↦ value
        Consume "GLYPH", G_BULLET
        Dim keyVal As String
        keyVal = Consume("STRING")("value")
        
        Consume "GLYPH", G_MAP
        
        Dim val As Variant
        AssignVariant val, Parse()
        
        If res.Exists(keyVal) Then res.Remove keyVal
        res.Add keyVal, val
        
        Set tok = Peek()
        If tok Is Nothing Then Err.Raise 5003, "PreJaSON", "Unterminated Object"
        
        If tok("type") = "GLYPH" And tok("value") = G_AND Then
            Consume "GLYPH", G_AND
        ElseIf tok("type") = "GLYPH" And tok("value") = G_OBJ_END Then
            Consume "GLYPH", G_OBJ_END
            Exit Do
        Else
             Err.Raise 5004, "PreJaSON", "Expected ∧ or ⟧, got " & tok("value")
        End If
    Loop
    Set ParseObject = res
End Function

' --- Tokenizer ---
Private Function Tokenize(ByVal inputStr As String) As Collection
    Dim col As New Collection
    Dim i As Long, L As Long
    Dim c As String, charCode As Long
    
    L = Len(inputStr)
    i = 1
    
    Do While i <= L
        c = Mid(inputStr, i, 1)
        charCode = AscW(c)
        
        ' Skip Whitespace
        If c = " " Or c = vbTab Or c = vbCr Or c = vbLf Then
            i = i + 1
        ' Handle SUB escape (next char is literal)
        ElseIf charCode = m_breakSUB Then
            i = i + 1
            If i > L Then Err.Raise 5009, "PreJaSON", "Unexpected end of input after SUB escape"
            Dim escapedChar As String
            escapedChar = Mid(inputStr, i, 1)
            If IsGlyph(escapedChar) Then
                col.Add CreateToken("ESCAPED_GLYPH", escapedChar)
            Else
                col.Add CreateToken("ESCAPED_CHAR", escapedChar)
            End If
            i = i + 1
        ' Handle ESC escape (next char literal after subtracting 0x40)
        ElseIf charCode = m_breakESC Then
            i = i + 1
            If i > L Then Err.Raise 5010, "PreJaSON", "Unexpected end of input after ESC escape"
            Dim nextEscChar As String
            nextEscChar = Mid(inputStr, i, 1)
            Dim unescapedCode As Long
            unescapedCode = AscW(nextEscChar) - &H40
            col.Add CreateToken("ESCAPED_CHAR", ChrW(unescapedCode))
            i = i + 1
        ' Structural Glyphs
        ElseIf IsGlyph(c) Then
            ' If String Start, read until End (handling escapes)
            If c = G_STR_START Then
                Dim strVal As String
                strVal = ""
                i = i + 1
                Do While i <= L
                    Dim curr As String
                    curr = Mid(inputStr, i, 1)
                    Dim currCode As Long
                    currCode = AscW(curr)
                    
                    ' Handle SUB escape within string
                    If currCode = m_breakSUB Then
                        i = i + 1
                        If i > L Then Err.Raise 5011, "PreJaSON", "Unterminated string (SUB at end)"
                        strVal = strVal & Mid(inputStr, i, 1)
                        i = i + 1
                    ' Handle ESC escape within string
                    ElseIf currCode = m_breakESC Then
                        i = i + 1
                        If i > L Then Err.Raise 5012, "PreJaSON", "Unterminated string (ESC at end)"
                        Dim nextCurr As String
                        nextCurr = Mid(inputStr, i, 1)
                        Dim unescCurrCode As Long
                        unescCurrCode = AscW(nextCurr) - &H40
                        strVal = strVal & ChrW(unescCurrCode)
                        i = i + 1
                    ' String end marker
                    ElseIf curr = G_STR_END Then
                        Exit Do
                    Else
                        strVal = strVal & curr
                        i = i + 1
                    End If
                Loop
                If i > L Then Err.Raise 5013, "PreJaSON", "Unterminated Gödel string literal"
                col.Add CreateToken("STRING", strVal)
                i = i + 1
            Else
                col.Add CreateToken("GLYPH", c)
                i = i + 1
            End If
        Else
            ' Atoms (Lojban / Numbers)
            Dim buffer As String
            buffer = ""
            Do While i <= L
                c = Mid(inputStr, i, 1)
                charCode = AscW(c)
                If c = " " Or c = vbTab Or c = vbCr Or c = vbLf Or IsGlyph(c) Or charCode = m_breakSUB Or charCode = m_breakESC Then Exit Do
                buffer = buffer & c
                i = i + 1
            Loop
            
            If buffer = ATOM_TRUE Then
                col.Add CreateToken("BOOL", True)
            ElseIf buffer = ATOM_FALSE Then
                col.Add CreateToken("BOOL", False)
            ElseIf buffer = ATOM_NULL Then
                col.Add CreateToken("NULL", Null)
            ElseIf IsNumeric(buffer) Then
                col.Add CreateToken("NUMBER", val(buffer))
            Else
                ' Unknown token, treat as raw text or error?
                ' For now, assume error in strict P-JSON
                Err.Raise 5005, "PreJaSON", "Unknown Token: " & buffer
            End If
        End If
    Loop
    
    Set Tokenize = col
End Function

' --- Helper Methods ---

Private Function IsGlyph(c As String) As Boolean
    IsGlyph = (c = G_OBJ_START Or c = G_OBJ_END Or c = G_ARR_START Or c = G_ARR_END Or _
               c = G_AND Or c = G_MAP Or c = G_BULLET Or c = G_STR_START Or c = G_STR_END)
End Function

Private Function CreateToken(sType As String, vVal As Variant) As Object
    Dim d As Object
    Set d = CreateObject("Scripting.Dictionary")
    d.Add "type", sType
    d.Add "value", vVal
    Set CreateToken = d
End Function

Private Function Peek() As Object
    If m_Cursor > m_Tokens.Count Then
        Set Peek = Nothing
    Else
        Set Peek = m_Tokens(m_Cursor)
    End If
End Function

Private Function Consume(Optional expectedType As String = "", Optional expectedVal As String = "") As Object
    Dim t As Object
    Set t = Peek()
    If t Is Nothing Then Err.Raise 5006, "PreJaSON", "Unexpected End of Stream"
    
    If expectedType <> "" Then
        If t("type") <> expectedType Then Err.Raise 5007, "PreJaSON", "Expected " & expectedType & ", got " & t("type")
    End If
    
    If expectedVal <> "" Then
        If t("value") <> expectedVal Then Err.Raise 5008, "PreJaSON", "Expected " & expectedVal & ", got " & t("value")
    End If
    
    m_Cursor = m_Cursor + 1
    Set Consume = t
End Function

' Escapes reserved glyphs and control characters using SUB prefix
Private Function EscapeString(ByVal str As String) As String
    Dim result As String
    Dim i As Long, L As Long
    Dim c As String, charCode As Long
    
    L = Len(str)
    result = ""
    
    For i = 1 To L
        c = Mid(str, i, 1)
        charCode = AscW(c)
        
        ' Escape reserved glyphs and control characters with SUB
        If IsGlyph(c) Or charCode = m_breakSUB Or charCode = m_breakESC Then
            result = result & ChrW(m_breakSUB) & c
        Else
            result = result & c
        End If
    Next i
    
    EscapeString = result
End Function

' Helper to assign Variant return types cleanly
Private Sub AssignVariant(ByRef dest As Variant, ByVal src As Variant)
    If IsObject(src) Then
        Set dest = src
    Else
        Let dest = src
    End If
End Sub






