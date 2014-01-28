program fLang;

{$IFDEF LINUX}
 {$mode objfpc}
{$ENDIF}

uses SysUtils;

type theVar=record
  Name:  string[32];
  Value: string[128];
end;

type theLabel=record
  Name: string[32];
  Addr: integer;
end;

type theFunc=record
  Name: string[32];
  Addr: integer;
end;

var
  returnAddress: array [1..255] of integer;
  code:          array of string[255];
  vars:          array of TheVar;
  labels:        array of TheLabel;
  funcs:         array of TheFunc;
  fileName, lastRezult: string;
  i, returnIndex, cyclesCount: integer;
  isDebug: boolean=false;

procedure VoidVar;
var j: integer;
begin
  for j:=1 to length(vars)-1 do begin
    vars[j].Name:='void';
    vars[j].Value:='';
  end;
end;

function SetVar(v_name, v_value: string):string;
var j: integer;
begin
  { The "_" perfix is only for system variatables }
  if v_name[1]='_' then begin
    WriteLn('[Error] ('+IntToStr(i)+'): Unacceptable name "'+v_name+'"');
    SetVar:='~break';
    exit;
  end;
  
  for j:=1 to length(vars)-1 do begin
    if (vars[j].Name='void') or (vars[j].Name=v_name) then begin
      vars[j].Name:=v_name;
      vars[j].Value:=v_value;
      SetVar:=v_value;
      break;
    end;
  end;
end;

function GetVarIndex(v_name: string):integer;
var j: integer;
begin
  GetVarIndex:=0;
    for j:=1 to length(vars)-1 do if vars[j].Name=v_name then begin
    GetVarIndex:=j;
    break;
  end;
end;

function GetVarValue(v_name: string):string;
var j: integer;
begin
  GetVarValue:='';
  for j:=1 to length(vars)-1 do if vars[j].Name=v_name then begin
    GetVarValue:=vars[j].Value;
    break;
  end;
end;

procedure SetLabel(l_name: string; l_address: integer);
var j: integer;
begin
  for j:=1 to length(labels)-1 do begin
    if (labels[j].Name='') or (labels[j].Name=l_name) then begin
      labels[j].Name:=l_name;
      labels[j].Addr:=l_address;
      break;
    end;
  end;
end;

function GetLabelAddr(l_name: string):integer;
var j: integer;
begin
  GetLabelAddr:=0;
  for j:=1 to length(labels)-1 do begin
    if labels[j].Name=l_name then begin
      GetLabelAddr:=labels[j].Addr;
      break;
    end;
  end;
end;

procedure SetFunc(f_name: string; f_address: integer);
var j: integer;
begin
  for j:=1 to length(funcs) do begin
    if (funcs[j].Name='') or (funcs[j].Name=f_name) then begin
      funcs[j].Name:=f_name;
      funcs[j].Addr:=f_address;
      break;
    end;
  end;
end;

function GetFuncAddr(f_name: string):integer;
var j: integer;
begin
  GetFuncAddr:=0;
  for j:=1 to length(funcs) do begin
    if funcs[j].Name=f_name then begin
      GetFuncAddr:=funcs[j].Addr;
      break;
    end;
  end;
end;

{ Function returns type of argument }
function TypeOf(inpStr: string):string;
var j: integer;
begin
  TypeOf:='int';
  if ((inpStr='true') or (inpStr='null') or (inpStr='')) then TypeOf:='bool';
  for j:=1 to length(InpStr) do begin
    if (inpStr[j]='.') then begin
      TypeOf:='float';
      break;
    end;
    if not (inpStr[j] in ['0'..'9','-','+']) then begin
      TypeOf:='string';
      break;
    end;
  end;
end;

{ Function extracts part of string before delimiter }
function StrHead(str: string; delimiter: string):string;
begin
  if pos(delimiter,str)<>0 then
    StrHead:=copy(str, 1, pos(delimiter, str)-length(delimiter))
  else
    StrHead:=str;
end;

{ Function extracts part of string after delimiter }
function StrTail(str: string; delimiter: string):string;
begin
  if pos(delimiter,str)<>0 then
    StrTail:=copy(str, pos(delimiter, str)+length(delimiter), length(str)-1)
  else
    StrTail:='';
end;

procedure Preproc(codeEnd: integer);
var j: integer;
    cStrHead, cStrTail: string;
begin
  i:=0;  // Set code pointer to first line
  j:=1;
  SetLength(vars, 1);    //  ||
  SetLength(labels, 1);  //  ||  Set array size to 1;
  SetLength(funcs, 1);   //  ||
  while(j<codeEnd) do begin
    cStrHead:=StrHead(code[j], ' ');
    cStrTail:=StrTail(code[j], ' ');
    if (cStrHead='--') then code[j]:='nop 0'; // Cut the comments
    if (cStrHead='func') and (cStrTail='main') then i:=j;
    if cStrHead='set'   then SetLength(vars, Length(vars)+1); // Set new var
    if cStrHead='label' then begin                 // Set new label
      SetLength(labels, Length(labels)+1);
      SetLabel(cStrTail, j);
    end;
    if cStrHead='func' then begin                  // Set new function
      SetLength(funcs, Length(funcs)+1);
      SetLength(vars, Length(vars)+2);
      SetFunc(cStrTail, j);
    end;
    inc(j);
  end;
  VoidVar;
end;

function ops(op: string):string;
var buf, temp: string;
begin
  buf:='';
  temp:=op;
  if isDebug then
    WriteLn('[Debug] (', i, '): Trying to ops `'+op+'`');
  if ((op[1]='"') and (op[length(op)]='"')) then
    temp:=copy(op, 2, length(op)-2) else
  if ((op[1]='[') and (op[length(op)]=']')) then begin
    buf:=copy(op, 2, length(op)-2);
    if buf='_last' then temp:=lastRezult else
    if buf='_ip'   then temp:=IntToStr(i) else
    if buf='_inp'  then repeat
      Write('> ');
      Readln(temp);
    until (temp<>'')
    else temp:=GetVarValue(buf);
  end;
  ops:=temp;
  if isDebug then
    Writeln('[Debug] (', i, '): Ops of `'+op+'` equals `'+temp+'`');
end;

function cclear(Expr: string):string;
var spFlag, qFlag: boolean;
    j: byte;
    buf: string;
begin
  qFlag:=false;  // Pointer in the "" block?
  spFlag:=true;  // Previous character is a space?
  buf:='';
  for j:=1 to length(Expr) do begin
    if Expr[j]='"' then qFlag:=not qFlag;
    if Expr[j]=' ' then begin
      if (spFlag=false) and (qFlag=false) then buf:=buf+Expr[j];
      spFlag:=true;
    end
    else spFlag:=false;
    if (spFlag=false) then buf:=buf+Expr[j];
    if (spFlag=true) and (qFlag=true) then buf:=buf+Expr[j];
  end;
  cclear:=buf;
end;

function OpenFile(fName: string; index: integer):integer;
var t: textfile;
    j: integer;
    buf: string;
begin
  OpenFile:=0;
  
  if not (FileExists(fName)) then fName:=fName+'.src';
  if not (FileExists(fName)) then Exit;
  assign(t,fName);
  reset(t);
  j:=index;

  while not EOF(t) do begin
    SetLength(code,length(code)+1);
    Readln(t,buf);
    buf:=cclear(buf);
    { Include a source file }
    if StrHead(buf,' ')='include' then j:=OpenFile(ops(StrTail(buf,' ')),j)
    else code[j]:=buf;
    inc(j);
  end;
  
  close(t);
  OpenFile:=j-1;
  Preproc(j-1);
end;

procedure MakeJump(Address: string);
begin
  if isDebug then    // Print a debug message
    WriteLn('[Debug] (', i, '): Making jump to `'+ Address +'`');
  if TypeOf(Address)='int' then i:=StrToInt(Address);
  if TypeOf(Address)='string' then i:=GetLabelAddr(Address);
end;

function m_add(op1, op2:string):string;
begin
  if(TypeOf(op1)='string') or (TypeOf(op2)='string') then begin
    Writeln('[Error] (', i,')  "'+op1+'" or "'+op2+'" is not a number. Program stopped');
   m_add:='~break';
   exit;
  end;
  if (TypeOf(op1)='float') or (TypeOf(op2)='float') then
  m_add:=FloatToStr(StrToFloat(op1)+StrToFloat(op2))
  else if (TypeOf(op1)='int') or (TypeOf(op2)='int') then
  m_add:=IntToStr(StrToInt(op1)+StrToInt(op2));
end;

function m_sub(op1, op2:string):string;
begin
  if (TypeOf(op1)='string') or (TypeOf(op2)='string') then begin
    Writeln('[Error] (', i,')  "'+op1+'" or "'+op2+'" is not a number. Program stopped');
    m_sub:='~break';
    exit;
  end;
  if (TypeOf(op1)='float') or (TypeOf(op2)='float') then
  m_sub:=FloatToStr(StrToFloat(op1)-StrToFloat(op2))
  else if (TypeOf(op1)='int') or (TypeOf(op2)='int') then
  m_sub:=IntToStr(StrToInt(op1)-StrToInt(op2));
end;

function m_mul(op1, op2:string):string;
begin
  if (TypeOf(op1)='string') or (TypeOf(op2)='string') then begin
    Writeln('[Error] (', i,')  "'+op1+'" or "'+op2+'" is not a number. Program stopped');
    m_mul:='~break';
    exit;
  end;
  if (TypeOf(op1)='float') or (TypeOf(op2)='float') then
  m_mul:=FloatToStr(StrToFloat(op1)*StrToFloat(op2))
  else if (TypeOf(op1)='int') or (TypeOf(op2)='int') then
  m_mul:=IntToStr(StrToInt(op1)*StrToInt(op2));
end;

function Execute(inpStr: string):string;
var fx, op1, op2, buf: string;
    j:integer;
begin
  Execute:='';

  {Extract operands from inpStr}
  while pos(', ',inpStr)<>0 do
    inpStr:=StringReplace(inpStr,', ',',',[rfreplaceall]);
  fx:=StrHead(inpStr,' ');   // fx contains operator name
  buf:=StrTail(inpStr,' ');
  op1:=StrHead(buf,',');     // op1 contains the first argument
  op2:=StrTail(buf,',');     // op2 contains the second argument

  {Check fx for user-defined function}
  if GetFuncAddr(fx)<>0 then begin
    if (returnIndex>255) then begin   // Check function call stack fill
      WriteLn('[Error] (', i, ') Stack owerflow at line');
      Execute:='~break';
      exit;
    end;
    if op1<>'' then SetVar(fx+'.x',ops(op1)); // Define the first argument as X
    if op2<>'' then SetVar(fx+'.y',ops(op2)); // Define the second argument as Y
    returnAddress[returnIndex]:=i;            // Set return adress
    inc(returnIndex);
    MakeJump(IntToStr(GetFuncAddr(fx)));      // Making jump to the function
  end;

  if fx='return' then begin
    if op1<>'' then Execute:=ops(op1);        // Check return data
    dec(returnIndex);
    if returnIndex=0 then begin
      Execute:='~break';
      exit;
    end;
    MakeJump(IntToStr(returnAddress[returnIndex]));
  end;

  { ! Experimental ! }
  if fx='unset' then begin
    SetVar(ops(op1), '');
    vars[GetVarIndex(ops(op1))].Name:='';
  end;

  if fx='eq'   then if ops(op1)<>ops(op2) then inc(i);
  if fx='neq'  then if ops(op1)=ops(op2)  then inc(i);
  if fx='less' then if ops(op1)>ops(op2)  then inc(i);
  if fx='more' then if ops(op1)<ops(op2)  then inc(i);

  if fx='div' then begin
    if (TypeOf(op1)='string') or (TypeOf(op2)='string') then begin
    Writeln('[Error] (', i,')  "'+op1+'" or "'+op2+'" is not a number. Program stopped');
    Execute:='~break';
    exit;
  end;
    if TypeOf(ops(op1))='float' then
      Execute:=FloatToStr(StrToFloat(ops(op1)) / StrToFloat(ops(op2)))
    else
      Execute:=IntToStr(StrToInt(ops(op1)) div StrToInt(ops(op2)));
  end;

  if fx='dbginfo' then begin
    WriteLn('[Debug] (', i, '): Generating debug info.');

    WriteLn('Variables');
    for j:=1 to Length(vars) do if vars[j].Name<>'' then Writeln(' Var['+
    IntToStr(j)+'] Name: `'+vars[j].name+'` Value: `'+vars[i].value+'`');

    WriteLn(' Functions');
    for j:=1 to Length(funcs) do if funcs[j].Name<>'' then Writeln('  Func['+
    IntToStr(j)+'] Name: `'+funcs[j].name+'` Address: `'+
    IntToStr(funcs[i].addr)+'`');

    WriteLn('[Debug] (', i, '): Debug info generated. Press any key to countinue.');
    ReadLn;
  end;

  if fx='debug' then if ops(op1)='on' then isDebug:=true else isDebug:=false;
  if fx='nop'   then Sleep(StrToInt(ops(op1)));
  if fx='out'   then if op2='/n' then WriteLn(ops(op1)) else Write(ops(op1));

  if fx='set'   then Execute:=SetVar(ops(op1), ops(op2));

  if fx='add'   then Execute:=m_add(ops(op1), ops(op2));
  if fx='sub'   then Execute:=m_sub(ops(op1), ops(op2));
  if fx='mul'   then Execute:=m_mul(ops(op1), ops(op2));

  if fx='mod'   then Execute:=IntToStr(StrToInt(ops(op1)) mod StrToInt(ops(op2)));

  if fx='conc'  then Execute:=ops(op1) + ops(op2);
  if fx='len'   then Execute:=IntToStr(length(ops(op1)));
  if fx='getc'  then Execute:=copy(ops(op1), StrToInt(ops(op2)),1);
  if fx='jmp'   then MakeJump(op1);
end;

procedure StartExec(FileName: string);
begin
  SetLength(code, 1);
  returnIndex:=1;
  cyclesCount:=0;
  WriteLn('[Info] Program started, '+IntToStr(OpenFile(FileName,1))+' strings loaded.');
  WriteLn;

  repeat
    inc(i);
    lastRezult:=Execute(code[i]);
    if isDebug=true then
      WriteLn('[Debug] (', i, '): Expression `', code[i], '` returns `', lastRezult, '`');
    Inc(cyclesCount);
  until (lastRezult='~break') or (i>=length(code));
  WriteLn;
  WriteLn('[Info] Program finished, '+IntToStr(cyclesCount)+' passes processed.');
end;

begin
  DecimalSeparator:='.';
  if FileExists(ParamStr(1)) then FileName:=ParamStr(1);
  WriteLn('fLang CLI v0.8.6g (15.01.2014), (C) Ramiil Hetzer');
  WriteLn('http://github.com/ramiil-kun/flang mailto:ramiil.kun@gmail.com');
  WriteLn('Syntax: '+ExtractFileName(ParamStr(0))+' [filename]');
  WriteLn;

  while (FileName='') do begin
    Write('File> ');
    Readln(FileName);
    if not ((FileExists(FileName)) or (FileExists(FileName+'.src'))) then FileName:='';
  end;
  StartExec(FileName);
  ReadLn;
end.
