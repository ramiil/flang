function m_add(op1, op2:string):string;
begin
  if(TypeOf(op1)='string') or (TypeOf(op2)='string') then begin
    ShowError('"'+op1+'" or "'+op2+'" is not a number.');
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
    ShowError('"'+ops(op1)+'" or "'+ops(op2)+'" is not a number.');
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
    ShowError('"'+op1+'" or "'+op2+'" is not a number.');
    m_mul:='~break';
    exit;
  end;
  if (TypeOf(op1)='float') or (TypeOf(op2)='float') then
  m_mul:=FloatToStr(StrToFloat(op1)*StrToFloat(op2))
  else if (TypeOf(op1)='int') or (TypeOf(op2)='int') then
  m_mul:=IntToStr(StrToInt(op1)*StrToInt(op2));
end;

function mathEval(fx, op1, op2:string):string;
begin
  if(TypeOf(op1)='string') then begin
    ShowError('"'+op1+'" is not a number.');
    mathEval:='~break';
    exit;
  end;
  if(TypeOf(op2)='string') then begin
    ShowError('"'+op2+'" is not a number.');
    mathEval:='~break';
    exit;
  end;
  showDebugMsg('op1 type `'+TypeOf(op1)+'`, op2 type `'+TypeOf(op2)+'`.');
  if (TypeOf(op1)='float') or (TypeOf(op2)='float') then begin
    if (fx='add') then mathEval:=FloatToStr(StrToFloat(op1) + StrToFloat(op2));
    if (fx='sub') then mathEval:=FloatToStr(StrToFloat(op1) - StrToFloat(op2));
    if (fx='mul') then mathEval:=FloatToStr(StrToFloat(op1) * StrToFloat(op2));
    if (fx='div') then mathEval:=FloatToStr(StrToFloat(op1) / StrToFloat(op2));
  end else
  if (TypeOf(op1)='int') and (TypeOf(op2)='int') then begin
    if (fx='add') then mathEval:=IntToStr(StrToInt(op1) + StrToInt(op2));
    if (fx='sub') then mathEval:=IntToStr(StrToInt(op1) - StrToInt(op2));
    if (fx='mul') then mathEval:=IntToStr(StrToInt(op1) * StrToInt(op2));
    if (fx='div') then mathEval:=FloatToStr(StrToInt(op1) / StrToInt(op2));
    if (fx='mod') then mathEval:=IntToStr(StrToInt(op1) mod StrToInt(op2));
  end; 
end;