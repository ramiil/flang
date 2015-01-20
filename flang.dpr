program fLang;

{$IFDEF LINUX}
  {$mode objfpc}
{$ENDIF}

uses SysUtils;

const
  BR = {$IFDEF LINUX} AnsiChar(#10) {$ENDIF}{$IFDEF MSWINDOWS} AnsiString(#13#10) {$ENDIF}; // Select newline code for different OS.

type theVar=record
  Name: string[32];
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
  code: array of string[255];
  vars: array of TheVar;
  labels: array of TheLabel;
  funcs: array of TheFunc;
  fileName, lastRezult: string;
  i, returnIndex, cyclesCount: integer;
  isDebug: boolean=false;
  isTrace: boolean=false;

procedure errorMsg(errorMsg: string);
begin
  WriteLn('[Error] ('+IntToStr(i)+'): '+errorMsg);
end;

procedure debugMsg(debugMsg: string);
begin
  if isDebug then
  WriteLn('[Debug] ('+IntToStr(i)+'): '+debugMsg);
end;

procedure clearVars;
var j: integer;
begin
  for j:=1 to length(vars)-1 do begin
    vars[j].Name:='void';
    vars[j].Value:='';
  end;
end;

function setVar(v_name, v_value: string): string;
var j: integer;
begin
  { The "_" perfix is only for system variatables }
  if v_name[1]='_' then begin
    errorMsg('Unacceptable name "'+v_name+'"');
    setVar:='~break';
    exit;
  end;

  for j:=1 to length(vars)-1 do begin
    if (vars[j].Name='void') or (vars[j].Name=v_name) then begin
      vars[j].Name:=v_name;
      vars[j].Value:=v_value;
      debugMsg('Variatable '+v_name+' takes value '+v_value);
      setVar:=v_value;
      break;
    end;
  end;
end;

function getVarIndex(v_name: string):integer;
var j: integer;
begin
  getVarIndex:=0;
    for j:=1 to length(vars)-1 do if vars[j].Name=v_name then begin
    getVarIndex:=j;
    break;
  end;
end;

function getVarValue(v_name: string):string;
var j: integer;
begin
  getVarValue:='';
  for j:=1 to length(vars)-1 do if vars[j].Name=v_name then begin
    getVarValue:=vars[j].Value;
    break;
  end;
end;

procedure UnsetVar(v_name: string);
var j: integer;
begin
  j:=getVarIndex(v_name);
  if j<>0 then begin
    vars[j].Name:='';
    vars[j].Value:='';
    debugMsg('Variatable '+v_name+' destroyed');
  end;
end;

procedure setLabel(l_name: string; l_address: integer);
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

function getLabelAddr(l_name: string):integer;
var j: integer;
begin
  getLabelAddr:=0;
  for j:=1 to length(labels)-1 do begin
    if labels[j].Name=l_name then begin
      getLabelAddr:=labels[j].Addr;
      break;
    end;
  end;
end;

procedure setFunc(f_name: string; f_address: integer);
var j: integer;
begin
  for j:=1 to length(funcs)-1 do begin
    if (funcs[j].Name='') or (funcs[j].Name=f_name) then begin
      funcs[j].Name:=f_name;
      funcs[j].Addr:=f_address;
      break;
    end;
  end;
end;

function getFuncAddr(f_name: string):integer;
var j: integer;
begin
  getFuncAddr:=0;
  for j:=1 to length(funcs)-1 do begin
    if funcs[j].Name=f_name then begin
      getFuncAddr:=funcs[j].Addr;
      break;
    end;
  end;
end;

{ Function returns type of argument }
function typeOf(inpStr: string):string;
var j: integer;
begin
  typeOf:='int';
  if ((inpStr='true') or (inpStr='null') or (inpStr='')) then typeOf:='bool';
  for j:=1 to length(InpStr) do begin
    if (inpStr[j]='.') then begin
      typeOf:='float';
      break;
    end;
    if not (inpStr[j] in ['0'..'9','-','+']) then begin
      typeOf:='string';
      break;
    end;
  end;
end;

{ Function extracts part of string before delimiter }
function strHead(str: string; delimiter: string):string;
begin
  if pos(delimiter,str)<>0 then
    strHead:=copy(str, 1, pos(delimiter, str)-length(delimiter))
  else
    strHead:=str;
end;

{ Function extracts part of string after delimiter }
function strTail(str: string; delimiter: string):string;
begin
  if pos(delimiter,str)<>0 then
    strTail:=copy(str, pos(delimiter, str)+length(delimiter), length(str)-1)
  else
    strTail:='';
end;

procedure Preproc(codeEnd: integer);
var j: integer;
    cStrHead, cStrTail: string;
begin
  i:=0; // Set code pointer to first line
  j:=1;
  SetLength(vars, 1);   // ||
  SetLength(labels, 1); // || Set array size to 1;
  SetLength(funcs, 1);  // ||
  while(j<codeEnd) do begin
    cStrHead:=strHead(code[j], ' ');
    cStrTail:=strTail(code[j], ' ');
    if (code[j]='') or ((code[j]=' ')) then code[j]:='nop 0';
    if (cStrHead='--') then code[j]:='nop 0'; // Cut the comments
    if (cStrHead='func') and (cStrTail='main') then i:=j;
    if cStrHead='set' then SetLength(vars, Length(vars)+1);// Set new var
    if cStrHead='label' then begin // Set new label
      SetLength(labels, Length(labels)+1);
      setLabel(cStrTail, j);
    end;
    if (cStrHead='func') and (cStrTail<>'main') then begin // Set new function
      SetLength(funcs, Length(funcs)+1);
      SetLength(vars, Length(vars)+2);
      setFunc(cStrTail, j);
    end;
    inc(j);
  end;
  clearVars;
end;

function ops(op: string):string;
var buf, temp: string;
begin
  buf:='';
  temp:=op;

  debugMsg('Trying to ops `'+op+'`');

  if ((op[1]='"') and (op[length(op)]='"')) then
    temp:=copy(op, 2, length(op)-2) else
  if ((op[1]='[') and (op[length(op)]=']')) then begin
    buf:=copy(op, 2, length(op)-2);
    if buf='_last' then temp:=lastRezult else
    if buf='_ip' then temp:=IntToStr(i) else
    if buf='_inp' then repeat
      Write('> ');
      Readln(temp);
    until (temp<>'')
    else temp:=getVarValue(buf);
  end;
  ops:=temp;

  debugMsg('Ops of `'+op+'` equals `'+temp+'`');

end;

function cclear(inpStr: string):string;
var spFlag, qFlag: boolean;
    j: byte;
    buf: string;
begin
  qFlag:=false; // Pointer in the "" block?
  spFlag:=true; // Previous character is a space?
  buf:='';

  for j:=1 to length(inpStr) do begin
    if inpStr[j]='"' then qFlag:=not qFlag;
    if inpStr[j]=' ' then begin
      if (spFlag=false) and (qFlag=false) then buf:=buf+inpStr[j];
      spFlag:=true;
    end else spFlag:=false;
    if (spFlag=false) then buf:=buf+inpStr[j];
    if (spFlag=true) and (qFlag=true) then buf:=buf+inpStr[j];
  end;
  while pos(', ', buf)<>0 do buf:=StringReplace(buf, ', ', ',', [rfreplaceall]);
  cclear:=buf;
end;

function openFile(fName: string; offset: integer):integer;
var t: textfile;
    j: integer;
    buf: string;
begin
  openFile:=0;

  if not (FileExists(fName)) then fName:=fName+'.src';
  if not (FileExists(fName)) then Exit;
  assign(t,fName);
  reset(t);
  j:=offset;

  while not EOF(t) do begin
    setLength(code,length(code)+1);
    Readln(t,buf);
    buf:=cclear(buf);
    { Include a source file }
    if strHead(buf,' ')='include' then j:=openFile(ops(strTail(buf,' ')),j)
    else code[j]:=buf;
    inc(j);
  end;

  close(t);
  openFile:=j-1;
  Preproc(j-1);
end;

procedure makeJump(Address: string);
begin

  debugMsg('Making jump to `'+ Address +'`');

  if typeOf(Address)='int' then i:=StrToInt(Address);
  if typeOf(Address)='string' then i:=getLabelAddr(Address);
end;

function mathEval(fx, op1, op2:string):string;
begin
  if(typeOf(op1)='string') then begin
    errorMsg('"'+op1+'" is not a number.');
    mathEval:='~break';
    exit;
  end;
  if(typeOf(op2)='string') then begin
    errorMsg('"'+op2+'" is not a number.');
    mathEval:='~break';
    exit;
  end;
  debugMsg('Types: op1 -> `'+typeOf(op1)+'`, op2 -> `'+typeOf(op2)+'`.');
  if (typeOf(op1)='float') or (typeOf(op2)='float') then begin
    if (fx='add') then mathEval:=FloatToStr(StrToFloat(op1) + StrToFloat(op2));
    if (fx='sub') then mathEval:=FloatToStr(StrToFloat(op1) - StrToFloat(op2));
    if (fx='mul') then mathEval:=FloatToStr(StrToFloat(op1) * StrToFloat(op2));
    if (fx='div') then mathEval:=FloatToStr(StrToFloat(op1) / StrToFloat(op2));
  end else
  if (typeOf(op1)='int') and (typeOf(op2)='int') then begin
    if (fx='add') then mathEval:=IntToStr(StrToInt(op1) + StrToInt(op2));
    if (fx='sub') then mathEval:=IntToStr(StrToInt(op1) - StrToInt(op2));
    if (fx='mul') then mathEval:=IntToStr(StrToInt(op1) * StrToInt(op2));
    if (fx='div') then mathEval:=FloatToStr(StrToInt(op1) / StrToInt(op2));
    if (fx='mod') then mathEval:=IntToStr(StrToInt(op1) mod StrToInt(op2));
  end;
end;

procedure genDbgInfo;
var j:integer;
begin
  WriteLn('[Debug] (', i, '): Generating debug info.');

  WriteLn('Variables');
  for j:=1 to Length(vars)-1 do if vars[j].Name<>'' then Writeln(' Var['+
  IntToStr(j)+'] Name: `'+vars[j].name+'` Value: `'+vars[j].value+'`');

  WriteLn('Functions');
  for j:=1 to Length(funcs)-1 do
    if funcs[j].Name<>'' then Writeln(' Func['+
    IntToStr(j)+'] Name: `'+funcs[j].name+'` Address: `'+
    IntToStr(funcs[j].addr)+'`');

  WriteLn('[Debug] (', i, '): Debug info generated. Press any key to countinue.');
  ReadLn;
end;	

function Execute(inpStr: string):string;
var fx, op1, op2, buf: string;
begin
  debugMsg('Execute expression `'+inpStr+'`');
  Execute:='';

  {Extract operands from inpStr and ops() it}
  fx:=ops(strHead(inpStr,' ')); // fx contains operator name
  buf:=strTail(inpStr,' ');
  op1:=ops(strHead(buf,',')); // op1 contains the first argument
  op2:=ops(strTail(buf,',')); // op2 contains the second argument

  {Check fx for user-defined function}
  if getFuncAddr(fx)<>0 then begin
    if (returnIndex>255) then begin // Check function call stack fill
      errorMsg('Function stack owerflow.');
      Execute:='~break';
      exit;
    end;
    if op1<>'' then setVar(fx+'.x',ops(op1)); // Define the first argument as X
    if op2<>'' then setVar(fx+'.y',ops(op2)); // Define the second argument as Y
    returnAddress[returnIndex]:=i; // Set return adress
    inc(returnIndex);
    MakeJump(IntToStr(getFuncAddr(fx))); // Making jump to the function
  end;

  if fx='return' then begin
    if op1<>'' then Execute:=ops(op1); // Check return data
    dec(returnIndex);
    if returnIndex=0 then begin
      Execute:='~break';
      exit;
    end;
    MakeJump(IntToStr(returnAddress[returnIndex]));
  end;

  if fx='unset' then UnsetVar(op1);

  if fx='eq'   then if not (op1=op2)  then inc(i);
  if fx='less' then if not (op1<op2)  then inc(i);
  if fx='more' then if not (op1>op2)  then inc(i);
  if fx='neq'  then if not (op1<>op2) then inc(i);
  if fx='leq'  then if not (op1<=op2) then inc(i);
  if fx='meq'  then if not (op1>=op2) then inc(i);


  if fx='dbginfo' then GenDbgInfo;

  if fx='debug' then if op1='on' then isDebug:=true else isDebug:=false;
  if fx='trace' then if op1='on' then isTrace:=true else isTrace:=false;
  if fx='nop' then Sleep(StrToInt(op1));
  if fx='out' then if op2='/n' then WriteLn(op1) else Write(op1);

  if fx='set' then Execute:=setVar(op1, op2);

  if ((fx = 'add') or (fx = 'sub') or (fx = 'mul') or (fx = 'div') or (fx = 'mod')) then
    Execute:=mathEval(fx, op1, op2);

  if fx='mod' then Execute:=IntToStr(StrToInt(op1) mod StrToInt(op2));

  if fx='conc' then Execute:=op1 + op2;
  if fx='len'  then Execute:=IntToStr(length(op1));
  if fx='getc' then Execute:=op1[StrToInt(op2)];
  if fx='chr'  then Execute:=chr(StrToInt(op1));
  if fx='ord'  then Execute:=IntToStr(ord(op1[1]));
  if fx='jmp'  then MakeJump(op1);

  if (Execute<>'') then debugMsg('Expression `'+code[i]+'` returns `'+Execute+'`.')
  else debugMsg('Expression `'+code[i]+'` is no-return function.')
end;

procedure runProgram(FileName: string);
begin
  SetLength(code, 1);
  returnIndex:=1;
  cyclesCount:=0;
  WriteLn('[Info] Program started, '+IntToStr(OpenFile(FileName, 1))+' strings loaded.'+BR);

  repeat
    inc(i);
    lastRezult:=Execute(code[i]);
    inc(cyclesCount);
    if isTrace then begin
      Writeln;
      Readln;
    end
  until (lastRezult='~break') or (i>=length(code));
  Write(BR+'[Info] Program finished, '+IntToStr(cyclesCount)+' passes processed.');
end;

begin
  DecimalSeparator:='.';
  if FileExists(ParamStr(1)+'.src') then FileName:=ParamStr(1)
  else begin
    WriteLn('fLang CLI v0.9.3 (20.01.15), (C) Ramiil Hetzer');
    WriteLn('https://github.com/ramiil-kun/flang mailto:ramiil.kun@gmail.com');
    WriteLn('Syntax: '+ExtractFileName(ParamStr(0))+' [filename]'+BR);
  end;

  while (FileName='') do begin
    Write('File> ');
    Readln(FileName);
    if not ((FileExists(FileName)) or (FileExists(FileName+'.src'))) then FileName:='';
  end;
  runProgram(FileName);
  ReadLn;
end.
