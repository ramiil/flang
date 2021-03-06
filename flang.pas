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
  Addr: longint;
end;

type theFunc=record
  Name: string[32];
  Addr: longint;
end;

var
  returnAddress: array [1..255] of longint;
  code:          array of string[255];
  vars:          array of theVar;
  labels:        array of theLabel;
  funcs:         array of theFunc;
  lastRezult:    string;
  codePtr, returnIndex, cyclesCount: longint;
  isDebug:  boolean=false;
  isTrace:  boolean=false;
  isFExit:  boolean=false;

procedure errorMsg(errorMsg: string);
begin
  Write(BR+'[Error] @'+IntToStr(codePtr)+': '+errorMsg);
end;

procedure debugMsg(debugMsg: string);
begin
  if isDebug then
  Write(BR+'[Debug] @'+IntToStr(codePtr)+': '+debugMsg);
end;

procedure cleanVars;
var j: longint;
begin
  for j:=1 to length(vars)-1 do begin
    vars[j].Name:='null';
    vars[j].Value:='';
  end;
end;

function getVarIndex(v_name: string):longint;
var j: longint;
begin
  getVarIndex:=0;
    for j:=1 to length(vars)-1 do if vars[j].Name=v_name then begin
    getVarIndex:=j;
    break;
  end;
end;

function setVar(v_name, v_value: string): string;
var v_index: longint = 0;
begin
  { The `_` perfix is only for r/o system Variables }
  if v_name[1]='_' then begin
    errorMsg('Unacceptable name `'+v_name+'`');  // All vars with _ as first character, are readonly
    setVar:='~break';
    exit;
  end;

  v_index:=getVarIndex(v_name); // Variable with same name is curerently exist
  if (v_index=0) then v_index:=getVarIndex('null'); // Empty variable is currently exist
  if (v_index=0) then begin
    SetLength(vars, length(vars)+1);  // Or make new cell for now variable
    v_index:=length(vars)-1;
  end;
  
  // Assign variable value to it's name
  vars[v_index].Name:=v_name;
  vars[v_index].Value:=v_value;
  debugMsg('Variable `'+v_name+'` takes value `'+v_value+'`');
  setVar:=v_value;
  
end;

function getVarValue(v_name: string):string;
var j: longint;
begin
  getVarValue:='';

  if v_name='_last' then getVarValue:=lastRezult else
  if v_name='_ip' then getVarValue:=IntToStr(codePtr) else
  if v_name='_inp' then repeat
    Write('> ');
    Readln(getVarValue);
  until (getVarValue<>'');

  for j:=1 to length(vars)-1 do if vars[j].Name=v_name then begin
    getVarValue:=vars[j].Value;
    break;
  end;
end;

procedure unsetVar(v_name: string);
var j: longint;
begin
  j:=getVarIndex(v_name);
  if j<>0 then begin
    vars[j].Name:='null';
    vars[j].Value:='';
    debugMsg('Variable '+v_name+' is free');
  end;
end;

procedure setLabel(l_name: string; l_address: longint);
var j: longint;
begin
  for j:=1 to length(labels)-1 do begin
    if (labels[j].Name='') or (labels[j].Name=l_name) then begin
      labels[j].Name:=l_name;
      labels[j].Addr:=l_address;
      break;
    end;
  end;
end;

function getLabelAddr(l_name: string):longint;
var j: longint;
begin
  getLabelAddr:=0;
  for j:=1 to length(labels)-1 do begin
    if labels[j].Name=l_name then begin
      getLabelAddr:=labels[j].Addr;
      break;
    end;
  end;
end;

procedure setFunc(f_name: string; f_address: longint);
var j: longint;
begin
  for j:=1 to length(funcs)-1 do begin
    if (funcs[j].Name='') or (funcs[j].Name=f_name) then begin
      funcs[j].Name:=f_name;
      funcs[j].Addr:=f_address;
      break;
    end;
  end;
end;

function getFuncAddr(f_name: string):longint;
var j: longint;
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
var j: longint;
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

procedure Preproc(codeEnd: longint);
var j: longint;
    cStrHead, cStrTail: string;
begin
  codePtr:=0; // Set code pointer to first line
  j:=1;
  SetLength(vars, 1);   // |
  SetLength(labels, 1); // | Set array size to 1;
  SetLength(funcs, 1);  // |
  while(j<codeEnd) do begin
    cStrHead:=strHead(code[j], ' ');
    cStrTail:=strTail(code[j], ' ');
    if (code[j]='') or ((code[j]=' ')) then code[j]:='nop 0';
    if (cStrHead='--') then code[j]:='nop 0'; // Cut the comments
    if (cStrHead='func') and (cStrTail='main') then codePtr:=j;
    //if cStrHead='set' then SetLength(vars, Length(vars)+1); // Set new var
    if cStrHead='label' then begin // Set new label
      SetLength(labels, Length(labels)+1);
      setLabel(cStrTail, j);
    end;
    if (cStrHead='func') and (cStrTail<>'main') then begin // Set new function
      SetLength(funcs, Length(funcs)+1);
      //SetLength(vars, Length(vars)+2);
      setFunc(cStrTail, j);
    end;
    inc(j);
  end;
  cleanVars;
end;

function extractVarValue(op: string):string;
var brOpen, delimiterPos: integer;
    buf: string;
begin

  brOpen:= LastDelimiter('[', op);

  if brOpen=0 then begin
    extractVarValue:=getVarValue(op);
    exit;
  end;

  buf:=op;

  buf:=copy(buf, brOpen+1, pos(']',  buf)-(brOpen+1));
  delimiterPos:=pos(buf, op);
  delete(op, delimiterPos, length(buf));
  insert(getVarValue(buf), op, delimiterPos);
  extractVarValue:=extractVarValue(op);
end;

function ops(op: string):string;
begin
  ops:=op;

  if op<>'' then debugMsg('Type of `'+op+'` is '+typeOf(op));

  if ((op[1]='"') and (op[length(op)]='"')) then
    ops:=copy(op, 2, length(op)-2) else
  if (op[1]='[') then begin
    ops:=extractVarValue(copy(op, 2, length(op)-2));
  end;

  if op<>'' then
    if ops=op then debugMsg('Maybe `'+op+'` is a constant')
    else debugMsg('`'+op+'` means `'+ops+'`');
end;

function cclear(inpStr: string):string;
var spFlag, qFlag: boolean;
    j: byte;
    buf: string;
begin
  { This code remove all extra spaces, except ones into quotes block. Black magic here }
  qFlag:=false; // Pointer in the `"` block?
  spFlag:=true; // Previous character is a space?
  buf:='';

  for j:=1 to length(inpStr) do begin
    if inpStr[j]='"' then qFlag:=not qFlag;
    if inpStr[j]=' ' then begin
      if ((spFlag=false) and (qFlag=false)) then buf:=buf+inpStr[j];
      spFlag:=true;
    end 
      else spFlag:=false;
    if (spFlag=false) then buf:=buf+inpStr[j];
    if (spFlag=true) and (qFlag=true) then buf:=buf+inpStr[j];
  end;
  while pos(', ', buf)<>0 do buf:=StringReplace(buf, ', ', ',', [rfreplaceall]);
  cclear:=buf;
end;

function openFile(fName: string; offset: longint):longint;
var sourceFile: textfile;
    j: longint;
    buf: string;
begin
  openFile:=0;

  assign(sourceFile, fName);
  reset(sourceFile);
  j:=offset;

  while not EOF(sourcefile) do begin
    setLength(code, length(code)+1);
    Readln(sourceFile, buf);
    buf:=cclear(buf);
    { Require code from another file }
    if strHead(buf, ' ')='include' then j:=openFile(ops(strTail(buf, ' ')), j)
    else code[j]:=buf;
    inc(j);
  end;

  close(sourceFile);
  openFile:=j-1;
  Preproc(j-1);
end;

procedure makeJump(Addr: string);
begin
  debugMsg('Make jump to address `'+ Addr +'`');

  if typeOf(Addr)='int'    then codePtr:=StrToInt(Addr);
  if typeOf(Addr)='string' then codePtr:=getLabelAddr(Addr);
end;

function mathEval(fx, op1, op2:string):string;
begin
  if(typeOf(op1)='string') then begin
    errorMsg('`'+op1+'` is not a number.');
    mathEval:='~break';
    exit;
  end;
  
  if(typeOf(op2)='string') then begin
    errorMsg('`'+op2+'` is not a number.');
    mathEval:='~break';
    exit;
  end;
  
  debugMsg('Types of: op1 -> `'+typeOf(op1)+'`, op2 -> `'+typeOf(op2)+'`.');
  
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
    if (fx='div') then mathEval:=FloatToStr(StrToInt(op1) div StrToInt(op2));
    if (fx='mod') then mathEval:=IntToStr(StrToInt(op1) mod StrToInt(op2));
  end;
end;

procedure genAllDump;
var j:longint;
begin
  debugMsg('Generating debug info.');

  WriteLn('Variables');
  for j:=1 to Length(vars)-1 do 
    //if vars[j].Name<>'null' then 
      Writeln(' Var['+IntToStr(j)+'] Name: `'+vars[j].name+'`, value: `'+vars[j].value+'`');

  WriteLn('Functions');
  for j:=1 to Length(funcs)-1 do
    //if funcs[j].Name<>'null' then 
      Writeln(' Func['+IntToStr(j)+'] Name: `'+funcs[j].name+'`, address: `'+IntToStr(funcs[j].addr)+'`');

  debugMsg('Debug info generated. Press any key to countinue.');
  ReadLn;
end;

function Execute(inpStr: string):string;
var fx, op1, op2, buf: string;
begin
  debugMsg('Execute expression `'+inpStr+'`');
  Execute:='';

  {Extract operands from inpStr and ops() it}
  fx:=strHead(inpStr,' '); // fx contains operator name
  buf:=strTail(inpStr,' ');
  op1:=ops(strHead(buf,',')); // op1 contains the first argument
  op2:=ops(strTail(buf,',')); // op2 contains the second argument

  {Check fx for user-defined function}
  if getFuncAddr(fx)<>0 then begin
    if (returnIndex>255) then begin // Check function call stack fill
      errorMsg('Call stack owerflow.');
      Execute:='~break';
      exit;
    end;
    if op1<>'' then setVar(fx+'.x',ops(op1)); // Define the first argument as X
    if op2<>'' then setVar(fx+'.y',ops(op2)); // Define the second argument as Y
    returnAddress[returnIndex]:=codePtr; // Set return adress
    inc(returnIndex);
    debugMsg('Call function `'+fx+'`');
    MakeJump(IntToStr(getFuncAddr(fx))); // Making jump to the function
  end;

  if fx='return' then begin
    if op1<>'' then Execute:=ops(op1)
    else Execute:='null'; // Check return data
    dec(returnIndex);
    if returnIndex=0 then begin
      Execute:='~break';
      exit;
    end;
    debugMsg('Exitting current function');
    MakeJump(IntToStr(returnAddress[returnIndex]));
  end;

  if fx='unset' then UnsetVar(op1);

  if fx='streq'  then if not (op1=op2)  then inc(codePtr);
  if fx='strneq' then if not (op1<>op2) then inc(codePtr);
  if fx='eq'     then if not (strToFloat(op1)=strToFloat(op2))  then inc(codePtr);
  if fx='less'   then if not (strToFloat(op1)<strToFloat(op2))  then inc(codePtr);
  if fx='more'   then if not (strToFloat(op1)>strToFloat(op2))  then inc(codePtr);
  if fx='neq'    then if not (strToFloat(op1)<>strToFloat(op2)) then inc(codePtr);
  if fx='leq'    then if not (strToFloat(op1)<=strToFloat(op2)) then inc(codePtr);
  if fx='meq'    then if not (strToFloat(op1)>=strToFloat(op2)) then inc(codePtr);


  if fx='alldump' then genAllDump;

  if fx='debug' then if op1='on' then isDebug:=true else isDebug:=false;
  if fx='trace' then if op1='on' then isTrace:=true else isTrace:=false;
  if fx='fexit' then if op1='on' then isFExit:=true else isFExit:=false;
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

  if (Execute<>'') then debugMsg('Expression `'+code[codePtr]+'` return `'+Execute+'`')
  else debugMsg('Expression `'+code[codePtr]+'` does not return any value')
end;

procedure runProgram(FileName: string);
begin
  SetLength(code, 1);
  returnIndex:=1;
  cyclesCount:=0;
  OpenFile(FileName, 1);

  repeat
    inc(codePtr);
    lastRezult:=Execute(code[codePtr]);
    inc(cyclesCount);
    if isTrace then begin
      Writeln;
      Readln;
    end
  until (lastRezult='~break') or (codePtr>=length(code));
  //if not isFExit then ReadLn();
end;

begin
  {$IFDEF MSWINDOWS} 
    DecimalSeparator:='.'; //For windows only
  {$ENDIF}
  if FileExists(ParamStr(1)) then  runProgram(ParamStr(1))
  else begin
    WriteLn('fLang CLI v0.9.7a (15 DEC 2015) Copyright (c) 2011-2015 Nikita Lindmann');
    WriteLn('https://github.com/ramiil-kun/flang mailto:ramiil.kun@gmail.com');
    WriteLn('Usage: ./'+ExtractFileName(ParamStr(0))+' [filename]');
  end;
end.