;
; dbform - by fliermate (aka MatQuasar) 2025/7
;
; Version history - v0.01 Initial release (without database support)
;                   v0.02 SQLite3 support, but with bugs in UPDATE and DELETE operations (INSERT and SELECT are OK)
;
; Reference:
; - https://learn.microsoft.com/en-us/windows/win32/controls/lbn-selchange
; - https://learn.microsoft.com/en-us/windows/win32/controls/lb-gettext
; - https://learn.microsoft.com/en-us/windows/win32/controls/create-a-simple-list-box
; - https://learn.microsoft.com/en-us/windows/win32/controls/lb-insertstring
; - https://learn.microsoft.com/en-us/windows/win32/controls/lb-deletestring
; - https://board.flatassembler.net/topic.php?t=20280 (Win32SQLite: a way to use SQLite with fasm)
; - https://learn.microsoft.com/en-us/windows/win32/controls/lb-getcount
;
format PE GUI 4.0
include 'win32a.inc'

IDD_MAIN = 100
IDC_VALUE = 101
IDC_ADD = 102
IDC_UPDATE = 103
IDC_REMOVE = 104
IDC_LIST= 105

section '.code' code readable executable

entry $

    invoke  GetModuleHandle,0
    invoke  DialogBoxParam,eax,IDD_MAIN,HWND_DESKTOP,DialogProc,0
    invoke  ExitProcess,0

DialogProc:
    push ebp
    mov  ebp, esp
    push ebx
    push esi
    push edi

    cmp     dword [ebp+12],WM_INITDIALOG
    je      .wminitdialog
    cmp     dword [ebp+12],WM_COMMAND
    je      .wmcommand
    cmp     dword [ebp+12],WM_CLOSE
    je      .wmclose
    xor     eax,eax
    jmp     .finish
.wminitdialog:
    invoke  GetDlgItem,[ebp+8], IDC_LIST
    mov     [_hwndlist],eax
    stdcall sql_init
    stdcall sql_select
    jmp     .processed
.wmcommand:
    cmp     dword [ebp+16],BN_CLICKED shl 16 + IDC_ADD
    je      .add
    cmp     dword [ebp+16],BN_CLICKED shl 16 + IDC_UPDATE
    je      .update
    cmp     dword [ebp+16],BN_CLICKED shl 16 + IDC_REMOVE
    je      .remove
    cmp     dword [ebp+16], LBN_SELCHANGE shl 16 + IDC_LIST
    je      .selchange
    jmp     .processed

.selchange:
    invoke  SendMessage, [_hwndlist], LB_GETCURSEL, 0, 0 ;Get selected index
;    invoke  SendMessage, [_hwndlist], LB_GETITEMDATA, eax, 0
    invoke  SendMessage, [_hwndlist], LB_GETTEXT, eax, _value
    invoke  SetDlgItemText,[ebp+8],IDC_VALUE, _value
    jmp     .processed

.add:
    invoke  GetDlgItemText,[ebp+8],IDC_VALUE, _value
    invoke  SendMessage, [_hwndlist], LB_ADDSTRING,0, _value
    invoke  SendMessage, [_hwndlist], LB_SETITEMDATA, eax, 0
    invoke  SendMessage, [_hwndlist], LB_GETCOUNT, 0, 0 
    mov     dword [_index], eax
    stdcall sql_add, _value, [_index]
    jmp     .processed
.update:
    invoke  GetDlgItemText,[ebp+8],IDC_VALUE, _value
    invoke  SendMessage, [_hwndlist], LB_GETCURSEL, 0, 0 ;Get selected index
    ;invoke  SendMessage, [_hwndlist], LB_GETITEMDATA, eax, 0
    invoke  SendMessage, [_hwndlist], LB_INSERTSTRING, eax, _value
    invoke  SendMessage, [_hwndlist], LB_GETCURSEL, 0, 0 ;Get selected index
    mov     dword [_index], eax
    invoke  SendMessage, [_hwndlist], LB_DELETESTRING, eax, 0
    stdcall sql_update, _value, [_index]
    jmp     .processed
.remove:
    invoke  SendMessage, [_hwndlist], LB_GETCURSEL, 0, 0 ;Get selected index
    mov     dword [_index], eax
    inc     dword [_index]
    ;invoke  SendMessage, [_hwndlist], LB_GETITEMDATA, eax, 0
    invoke  SendMessage, [_hwndlist], LB_DELETESTRING, eax, 0
    ;dec     dword [_index]
    stdcall sql_delete, [_index]
    jmp     .processed

.wmclose:
    invoke  EndDialog,[ebp+8],0
.processed:
    mov     eax,1
.finish:
    pop edi
    pop esi
    pop ebx
    leave
    retn 16

proc sql_init
     push ebx
     push esi
     push edi
     cinvoke  sqlite3_open, _filename, _handle
     cinvoke  sqlite3_exec, [_handle], _sql_create, 0, 0, _dummy
     cinvoke  sqlite3_close, [_handle]
     pop edi
     pop esi
     pop ebx
     ret
endp

proc sql_add,field,recnum
     push ebx
     push esi
     push edi
     cinvoke  sqlite3_open, _filename, _handle
     cinvoke  wsprintf, _sql, _sql_add, [recnum], [field]
     cinvoke  sqlite3_exec, [_handle], _sql, 0, 0, _dummy
     cinvoke  sqlite3_close, [_handle]
     pop edi
     pop esi
     pop ebx
     ret
endp

proc sql_update,field,recnum
     push ebx
     push esi
     push edi
     cinvoke  sqlite3_open, _filename, _handle
     cinvoke  wsprintf, _sql, _sql_update, [field], [recnum]
     cinvoke  sqlite3_exec,  [_handle], _sql, 0, 0, _dummy
     cinvoke  sqlite3_close, [_handle]
     pop edi
     pop esi
     pop ebx
     ret
endp

proc sql_delete,recnum
     push ebx
     push esi
     push edi
     cinvoke  sqlite3_open, _filename, _handle
     cinvoke  wsprintf, _sql, _sql_delete, [recnum]
     cinvoke  sqlite3_exec, [_handle], _sql, 0, 0, _dummy
     cinvoke  sqlite3_close, [_handle]
     pop edi
     pop esi
     pop ebx
     ret
endp

proc sql_select
     push ebx
     push esi
     push edi
     cinvoke  sqlite3_open, _filename, _handle
     cinvoke  sqlite3_get_table, [_handle], _sql_select, _result, _row, _col, NULL
     mov      ecx, [_row]
     or       ecx, ecx
     jz       .done
     mov      edx, dword [_result]
     add      edx, 8   ;skip first row (column headers)
.repeat:
     add      edx, 4   ;two columns per row - skip primary key
     push     edx
     push     ecx
     invoke   SendMessage, [_hwndlist], LB_ADDSTRING,0, [edx]
     pop      ecx
     pop      edx
     add      edx, 4   ;two columns per row - jump to next row
     loop     .repeat
     cinvoke  sqlite3_free_table, dword [_result]
     cinvoke  sqlite3_close, [_handle]
.done:
     pop edi
     pop esi
     pop ebx
     ret
endp

section '.data' data readable writeable

_filename    db 'dbform1.dat',0
_sql_create  db 'CREATE TABLE IF NOT EXISTS main (a integer, b text)',0
_sql_add     db "INSERT INTO main (a, b) VALUES (%d,'%s');",0
_sql_delete  db "DELETE FROM main WHERE a=%d ;",0   ;If you omit the WHERE clause, all records in the table will be deleted!
_sql_select  db "SELECT * FROM main;",0
_sql_update  db "UPDATE main SET b='%s' WHERE a=%d ;",0
_dummy       dd 0
_handle      dd 0
_hwndlist    dd 0
_row         dd 0
_col         dd 0
_index       dd 0
_sql         rb 512
_value       rb 256
_result      rb 2048

section '.idata' import readable

    library   kernel32,'kernel32.DLL', user32,'user32.DLL', sqlite, 'sqlite3.DLL'
    include  'api\kernel32.inc'
    include  'api\user32.inc'

    import    sqlite,\
              sqlite3_libversion, 'sqlite3_libversion',\
              sqlite3_open, 'sqlite3_open',\
              sqlite3_exec, 'sqlite3_exec',\
              sqlite3_get_table, 'sqlite3_get_table',\
              sqlite3_free_table,'sqlite3_free_table',\
              sqlite3_close,'sqlite3_close'

section '.rsrc' resource data readable

     directory  RT_DIALOG, dialogs

     resource   dialogs, IDD_MAIN, LANG_ENGLISH + SUBLANG_DEFAULT, mainform

     dialog  mainform,'dbform',0,0,300,200, DS_CENTER + WS_CAPTION + WS_SYSMENU
     dialogitem 'Button','Main',-1,10,10,280,180,WS_VISIBLE + BS_GROUPBOX
     dialogitem 'Button','Add',IDC_ADD,200,30,70,15,WS_VISIBLE + BS_DEFPUSHBUTTON
     dialogitem 'Button','Update',IDC_UPDATE,200,50,70,15,WS_VISIBLE
     dialogitem 'Button','Remove',IDC_REMOVE,200,70,70,15,WS_VISIBLE
     dialogitem 'STATIC','Value',-1,30,30,100,15,WS_VISIBLE
     dialogitem 'EDIT','0',IDC_VALUE,30,40,150,15,WS_VISIBLE+WS_BORDER+WS_TABSTOP+ES_AUTOHSCROLL
     dialogitem 'LISTBOX','0',IDC_LIST,30,100,240,90,WS_VISIBLE+WS_TABSTOP+WS_BORDER+LBS_NOTIFY+WS_VSCROLL
enddialog