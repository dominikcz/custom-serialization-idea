unit serialization;

interface

uses
  mORMot,
  SynCommons,
  System.Generics.Defaults,
  System.Generics.Collections,
  system.Rtti;

type
  TSerializerCustomReader = function(const aValue: TObject; aFrom: PUTF8Char; var aValid: Boolean; aOptions: TJSONToObjectOptions): PUTF8Char of object;
  TSerializerCustomWriter = procedure(const aSerializer: TJSONSerializer; aValue: TValue; aOptions: TTextWriterWriteObjectOptions) of object;

  TCustomSerializationParser = record
    Reader: TSerializerCustomReader;
    Writer: TSerializerCustomWriter;
  end;

  TSerializer = class
  private
    // readers are not implemented in this example so here is just a stab
    class function DummyReader(const aValue: TObject; aFrom: PUTF8Char; var aValid: Boolean; aOptions: TJSONToObjectOptions): PUTF8Char;

    class procedure CurrencyWriter(const aSerializer: TJSONSerializer; aValue: TValue; aOptions: TTextWriterWriteObjectOptions);
    class procedure DateTimeWriter(const aSerializer: TJSONSerializer; aValue: TValue; aOptions: TTextWriterWriteObjectOptions);
    class procedure StringWriter(const aSerializer: TJSONSerializer; aValue: TValue; aOptions: TTextWriterWriteObjectOptions);
  public
    class procedure ObjectWriter(const aSerializer: TJSONSerializer; aValue: TObject; aOptions: TTextWriterWriteObjectOptions);
    class function ObjectReader(const aObject: TObject; aFrom: PUTF8Char; var aValid: Boolean;
      aOptions: TJSONToObjectOptions) : PUTF8Char;

    class function ObjectToJSON(AObject: TObject): string;
    class function JsonToObject<T:class, constructor>(AJson: string): T;
    class procedure UpdateObjectFormJson<T:class, constructor>(AObject: TObject; AJson: string);
    class procedure RegisterCustomType(aTypeInfo: pointer; aReader: TSerializerCustomReader; aWriter: TSerializerCustomWriter);
    class procedure UnRegisterCustomType(aTypeInfo: pointer);
  end;

implementation

uses
  reflections,
  System.TypInfo,
  System.Types,
  System.SysUtils,
  System.StrUtils,
  DateUtils;

var
  vGlobalCustomTypeParsers: TDictionary<pointer, TCustomSerializationParser>;

class procedure TSerializer.CurrencyWriter(const aSerializer: TJSONSerializer; aValue: TValue;
  aOptions: TTextWriterWriteObjectOptions);
begin
  aSerializer.AddCurr64(aValue.AsType<Currency>);
end;

class procedure TSerializer.DateTimeWriter(const aSerializer: TJSONSerializer; aValue: TValue;
  aOptions: TTextWriterWriteObjectOptions);
var
  LDatetime: TDateTime;
begin
  if aValue.AsExtended = 0 then
  begin
    aSerializer.AddJSONEscapeString('null');
  end
  else if aValue.TypeInfo = TypeInfo(TDateTime) then
  begin
    aSerializer.Add('"');
    LDatetime := aValue.AsType<TDateTime>;
    aSerializer.AddDateTime(@LDatetime, ' ');
    aSerializer.Add('"');
  end
  else if aValue.TypeInfo = TypeInfo(TDate) then
  begin
    aSerializer.Add('"');
    aSerializer.AddString(DateToStr(aValue.AsType<TDate>));
    aSerializer.Add('"');
  end
  else if aValue.TypeInfo = TypeInfo(TTime) then
  begin
    aSerializer.Add('"');
    aSerializer.AddJSONEscapeString(TimeToStr(aValue.AsType<TTime>));
    aSerializer.Add('"');
  end;
end;

class function TSerializer.DummyReader(const aValue: TObject; aFrom: PUTF8Char; var aValid: Boolean;
  aOptions: TJSONToObjectOptions): PUTF8Char;
begin
//
end;

class function TSerializer.JsonToObject<T>(AJson: string): T;
var
  valid: Boolean;
  jsonUtf8Str: rawUTF8;
  AObject: TObject;
begin
  Result := nil;
  if (AJson = '{}') or (AJson.ToLower = 'null') then
    exit;
  jsonUtf8Str := StringToUTF8(Ajson);
  AObject := T.Create;
  mORMot.JSONToObject(AObject, putf8char(jsonUtf8Str), valid, T);
  result := T(AObject);
end;

class function TSerializer.ObjectReader(const aObject: TObject; aFrom: PUTF8Char;
  var aValid: Boolean; aOptions: TJSONToObjectOptions): PUTF8Char;
var
  Values: TPUtf8CharDynArray;
  Names: array of PUTF8Char;
  NamesStr: array of AnsiString;
  i, j, iVal, valuePos, startPos: integer;
  keyVal: string;
  properties: TPropertyInfoList;
  prop, propStr, strVal, strValParsed, jsonStr: string;
  LProperty: TRttiProperty;
  LValue: TValue;
  subObj: TObject;
  LMethod: TRttiMethod;
  LType, LKeyType, LValueType: TRttiType;
  listItem: TObject;
  &type: TClass;
  json: PUTF8Char;
  LField: TRttiField;
  strArr: System.Types.TStringDynArray;
  attr: TArray<TCustomAttribute>;
  lOwnsObjects: boolean;

  procedure ReadValue(var aValue: TValue; AStrVal: string);
  var
    enumVal: integer;
  begin
    case aValue.Kind of
      tkInteger, tkInt64:
        begin
          aValue := TValue.FromOrdinal(aValue.TypeInfo, StrToInt64(AStrVal));
        end;
      tkString, tkLString, tkWString, tkUString:
        begin
          aValue := TValue.From<string>(trim(AStrVal));
        end;
      tkChar, tkWChar:
        begin
          TValue.Make(@AStrVal, aValue.TypeInfo, aValue);
        end;
      tkEnumeration:
        begin
          if (TryStrToInt(AStrVal, enumVal)) and (Length(AStrVal) > 0) then
            aValue := TValue.FromOrdinal(aValue.TypeInfo, enumVal)
          else
            aValue := TValue.FromOrdinal(aValue.TypeInfo,
              GetEnumValue(aValue.TypeInfo, AStrVal));
        end;
      tkFloat:
        begin
          if aValue.TypeInfo = TypeInfo(TDateTime) then
            aValue := TValue.From<TDateTime>(StrToDateTime(AStrVal))
          else if aValue.TypeInfo = TypeInfo(TDate) then
            aValue := TValue.From<TDate>(DateOf(StrToDateTime(AStrVal)))
          else if aValue.TypeInfo = TypeInfo(TTime) then
            aValue := TValue.From<TTime>(TimeOf(StrToDateTime(AStrVal)))
          else
            aValue := TValue.From<Currency>(StrToCurr(AStrVal))
        end;
      tkSet:
        begin
          TValue.Make(StringToSet(aValue.TypeInfo, AStrVal),
            aValue.TypeInfo, aValue);
        end;
      tkClass,
        tkInterface,
        tkMethod:
        ;
    end;
  end;

  function CreateSubObject(val: TRttiInstanceType): TObject;
  var
    constructorMethod: TRttiMethod;
  begin
    if (val.MetaclassType.ClassName.StartsWith('TObjectList')) or
      (val.MetaclassType.ClassParent.ClassName.StartsWith('TObjectList')) then
    begin
      result := TReflection.InvokeObjectListConstructor(val, True);
    end
    else
    if TReflection.tryGetSimpleConstructor(val, constructorMethod) then
    begin
      result := constructorMethod.Invoke(val.MetaclassType, []).AsObject;
    end
    else
      raise Exception.Create('Unable to call default constructor');
  end;

begin
  aValid := false;
  &type := aObject.ClassType;
  subObj := nil;
  jsonStr := UTF8DecodeToString(aFrom, length(aFrom));

  if jsonStr.StartsWith('[') then
  begin
   if TReflection.TryGetProperty(aObject, 'OwnsObjects', LProperty) then
   begin
     lOwnsObjects := TReflection.GetPropertyValue(aObject, LProperty.Name);
   end;
  end;

  if jsonStr.StartsWith('[')
    and TReflection.TryGetMethod(aObject, 'Add', LMethod)
    AND (jsonStr <> '[]') then
  begin
    LType := LMethod.GetParameters[0].ParamType;
    if LType.IsInstance then
    begin
      &type := LType.AsInstance.MetaclassType;
      repeat
        listItem := CreateSubObject(LType.AsInstance);
        aFrom := mORMot.JsonToObject(listItem, aFrom, aValid, &type);
        LMethod.Invoke(aObject, [TValue.From(listItem)]);
      until (aFrom = nil) or (aFrom^ = ']');
      exit;
    end
    else
    begin
     strVal := Copy(aFrom, 2, Pos(']', aFrom) - 2);
     strArr := SplitString(strVal, ',');

     for i := low(strArr) to high(strArr) do
      begin
        if strArr[i].StartsWith('"') and strArr[i].EndsWith('"') then
          strValParsed := Copy(strArr[i], 2, Length(strArr[i])-2)
        else
          strValParsed := strArr[i];
        TValue.Make(nil, lType.Handle, lValue);
        ReadValue(LValue, strValParsed);
        LMethod.Invoke(aObject, [LValue]);
      end;
      Result := GotoNextJSONItem(aFrom);
      exit;
    end;

  end;

  properties := TReflection.GetProperties(&type);
  i := 0;
  SetLength(Names, properties.Keys.Count);
  SetLength(NamesStr, properties.Keys.Count);
  for prop in properties.Keys.ToArray do
  begin
    NamesStr[i] := prop;
    inc(i);
  end;
  for i := 0 to length(NamesStr) - 1 do
    Names[i] := pointer(NamesStr[i]);

  aFrom := JSONDecode(aFrom, Names, Values, True);

  for i := low(Names) to high(Names) do
  begin
    LProperty := nil;
    LField := nil;
    prop := Names[i];
    strVal := UTF8DecodeToString(Values[i], length(Values[i]));
    if length(strVal) = 0 then
      continue;
    LProperty := nil;

    if strVal.StartsWith('{') or strVal.StartsWith('[') then
    begin

      if TReflection.TryGetProperty(aObject, prop, LProperty) then
      begin
        subObj := nil;
        if LProperty.IsWritable and LProperty.PropertyType.IsInstance then
        begin
          if LProperty.PropertyType.AsInstance.MetaclassType.ClassName.StartsWith('TObjectDictionary') or
            LProperty.PropertyType.AsInstance.MetaclassType.ClassName.StartsWith('TDictionary') or
            LProperty.PropertyType.AsInstance.MetaclassType.ClassParent.ClassName.StartsWith('TDictionary') then
            continue;

          subObj := LProperty.GetValue(aObject).AsObject;
          if subObj = nil then
          begin
            subObj := CreateSubObject(LProperty.PropertyType.AsInstance);
          end;
        end
        else
          continue;
      end
      else if TReflection.TryGetField(aObject, prop, LField) then
      begin
        if LField.FieldType.IsInstance then
        begin
          if LField.FieldType.AsInstance.MetaclassType.ClassName.StartsWith('TObjectDictionary') or
           LField.FieldType.AsInstance.MetaclassType.ClassName.StartsWith('TDictionary') or
             LField.FieldType.AsInstance.MetaclassType.ClassParent.ClassName.StartsWith('TDictionary') then
            continue;
          subObj := LField.GetValue(aObject).AsObject;
          if subObj = nil then
          begin
            subObj := CreateSubObject(LField.FieldType.AsInstance);
          end;
        end
        else if LField.FieldType.TypeKind in [tkString, tkUString] then
        begin
          LValue := LField.GetValue(aObject);
          ReadValue(LValue, strVal);
          LField.SetValue(aObject, LValue);
          continue;
        end
        else
          Continue;
      end;

      ObjectReader(subObj, PUTF8Char(StringToUTF8(strVal)), aValid, aOptions);

      if (LField <> nil) then
        LField.SetValue(aObject, TValue.From(subObj))
      else if (LProperty <> nil) and (LProperty.IsWritable) then
        LProperty.SetValue(aObject, TValue.From(subObj));
    end
    else
    begin
      if TReflection.TryGetField(aObject, prop, LField) then
      begin
        LValue := LField.GetValue(aObject);
        ReadValue(LValue, strVal);
        LField.SetValue(aObject, LValue);
      end;
      if TReflection.TryGetProperty(aObject, prop, LProperty) then
      begin
        if not LProperty.IsWritable then continue;
        LValue := LProperty.GetValue(aObject);
        ReadValue(LValue, strVal);
        LProperty.SetValue(aObject, LValue);
      end;
    end;
  end;
  aValid := True;
  result := aFrom;
  properties.Free;
end;

class function TSerializer.ObjectToJSON(AObject: TObject): string;
begin
  result := UTF8ToString(SynCommons.ObjectToJSON(AObject, [woHumanReadable, woDontStoreDefault]));
end;

class procedure TSerializer.ObjectWriter(const aSerializer: TJSONSerializer; aValue: TObject; aOptions: TTextWriterWriteObjectOptions);
var
  C: TRtticontext;
  val: TValue;
  P: TRttiProperty;
  F: TRttiField;
  M: TRttiMethod;
  LEnumerator: TValue;
  LMethod: TRttiMethod;
  LFreeEnumerator: Boolean;
  LType: TRttiType;
  LProperty: TRttiProperty;
  LValue: TValue;
  attr: TArray<TCustomAttribute>;
  i: integer;
  isNotSerialized: Boolean;
  strVal: string;
  ttt: TRttiType;

  procedure WriteValue(aVal: TValue);
  var
    LObj: TObject;
    LEnumerator: TValue;
    LMethod: TRttiMethod;
    LFreeEnumerator: Boolean;
    LType: TRttiType;
    LProperty: TRttiProperty;
    LValue: TValue;
    lI: integer;
    i: integer;
    parser: TCustomSerializationParser;
  begin
    with aSerializer do
    begin
      if vGlobalCustomTypeParsers.TryGetValue(aVal.TypeInfo, parser) then
      begin
        parser.Writer(aSerializer, aVal, aOptions);
        exit;
      end;

      case aVal.TypeInfo.Kind of
        tkMethod, tkInterface:
          ;
        tkEnumeration:
          begin
            if val.IsType<Boolean> then
              AddShort(LowerCase(val.ToString))
            else
            begin
              Add('"');
              AddJSONEscapeString(val.ToString);
              Add('"');
            end

          end;
        tkRecord: begin
          AddRecordJSON(aVal, aVal.TypeInfo);
        end;
        tkClass:
          begin
            LObj := val.AsObject;
            if (TReflection.TryGetProperty(LObj, 'List', LProperty)) or
              (TReflection.TryGetProperty(LObj, 'OwnsObjects', LProperty)) then
            begin
              if TReflection.TryGetMethod(LObj, 'GetEnumerator', LMethod) then
              begin
                Add('[');
                LEnumerator := LMethod.Invoke(LObj, []);
                LFreeEnumerator := LEnumerator.IsObject;
                try
                  LType := LEnumerator.RttiType;
                  if LType is TRttiInterfaceType then
                  begin
                    LEnumerator := LEnumerator.ToObject;
                    LType := LEnumerator.RttiType;
                  end;
                  if TReflection.TryGetMethod(LType, 'MoveNext', LMethod) and
                    TReflection.TryGetProperty(LType, 'Current', LProperty) then
                  begin
                    while LMethod.Invoke(LEnumerator, []).AsBoolean do
                    begin
                      LValue := LProperty.GetValue(pointer(LEnumerator.AsObject));
                      ObjectWriter(aSerializer, LValue.AsObject, aOptions);
                      Add(',');
                    end;
                    CancelLastComma;
                  end;
                  Add(']');
                finally
                  if LFreeEnumerator then
                    LEnumerator.AsObject.Free();
                end;
              end;
            end
            else if Assigned(LObj) then
              ObjectWriter(aSerializer, LObj, aOptions)
            else
            begin
              AddJSONEscapeString('null');
            end;
          end;
          tkDynArray: begin
            Add('[');
            for lI := 0 to aVal.GetArrayLength - 1 do
              begin
                WriteValue(aVal.GetArrayElement(lI));
                if lI <> aVal.GetArrayLength - 1 then
                  Add(',');
              end;
            Add(']');
          end
      else
        begin
          AddJSONEscapeString(aVal.AsVariant);
        end;
      end;
    end;
  end;

begin
  with aSerializer do
  begin
    C := TRtticontext.Create;
    if (TReflection.PropertyExists(aValue, 'List')) or
      (TReflection.PropertyExists(aValue, 'OwnsObjects')) then
    begin
      if TReflection.TryGetMethod(aValue, 'GetEnumerator', LMethod) then
      begin
        Add('[');
        LEnumerator := LMethod.Invoke(aValue, []);
        LFreeEnumerator := LEnumerator.IsObject;
        try
          LType := LEnumerator.RttiType;
          if LType is TRttiInterfaceType then
          begin
            LEnumerator := LEnumerator.ToObject;
            LType := LEnumerator.RttiType;
          end;
          if TReflection.TryGetMethod(LType, 'MoveNext', LMethod) and
            TReflection.TryGetProperty(LType, 'Current', LProperty) then
          begin
            while LMethod.Invoke(LEnumerator, []).AsBoolean do
            begin
              LValue := LProperty.GetValue
                (pointer(LEnumerator.AsObject));
              ObjectWriter(aSerializer, LValue.AsObject, aOptions);
              Add(',');
            end;
            CancelLastComma;
          end;
          Add(']');
        finally
          if LFreeEnumerator then
            LEnumerator.AsObject.Free();
        end;
      end;
    end
    else
    begin
      Add('{');
      for P in C.GetType(aValue.ClassType).GetProperties do
      begin
        if P.Visibility >= mvPublic then
        begin
          AddPropName(P.Name);
          val := P.GetValue(pointer(aValue));
          WriteValue(val);
          Add(',');
        end;
      end;
      for F in C.GetType(aValue.ClassType).GetFields do
      begin
        if F.Visibility >= mvPublic then
        begin
          AddPropName(F.Name);
          val := F.GetValue(pointer(aValue));
          WriteValue(val);
          Add(',');
        end;
      end;
      CancelLastComma;
      Add('}');
    end;

  end;
end;

class procedure TSerializer.RegisterCustomType(aTypeInfo: pointer; aReader: TSerializerCustomReader; aWriter: TSerializerCustomWriter);
var
  parser: TCustomSerializationParser;
begin
  parser.Reader := aReader;
  parser.Writer := aWriter;
  vGlobalCustomTypeParsers.AddOrSetValue(aTypeInfo, parser);
end;

class procedure TSerializer.StringWriter(const aSerializer: TJSONSerializer; aValue: TValue;
  aOptions: TTextWriterWriteObjectOptions);
begin
  aSerializer.Add('"');
  aSerializer.AddJSONEscapeString(aValue.AsString);
  aSerializer.Add('"');
end;

class procedure TSerializer.UnRegisterCustomType(aTypeInfo: pointer);
begin
  vGlobalCustomTypeParsers.Remove(aTypeInfo);
end;

class procedure TSerializer.UpdateObjectFormJson<T>(AObject: TObject;
  AJson: string);
var
  jsonUtf8Str: RawUTF8;
  valid: boolean;
begin
  jsonUtf8Str := StringToUTF8(Ajson);
  mORMot.JSONToObject(AObject, putf8char(jsonUtf8Str), valid, T);
end;

initialization

  vGlobalCustomTypeParsers := TDictionary<pointer, TCustomSerializationParser>.Create();

  TJSONSerializer.RegisterCustomSerializer(TObject, TSerializer.ObjectReader, TSerializer.ObjectWriter);

  TSerializer.RegisterCustomType(typeinfo(Currency), TSerializer.DummyReader, TSerializer.CurrencyWriter);
  TSerializer.RegisterCustomType(typeinfo(TDate), TSerializer.DummyReader, TSerializer.DateTimeWriter);
  TSerializer.RegisterCustomType(typeinfo(TTime), TSerializer.DummyReader, TSerializer.DateTimeWriter);
  TSerializer.RegisterCustomType(typeinfo(TDateTime), TSerializer.DummyReader, TSerializer.DateTimeWriter);
  TSerializer.RegisterCustomType(typeinfo(string), TSerializer.DummyReader, TSerializer.StringWriter);
  TSerializer.RegisterCustomType(typeinfo(ansistring), TSerializer.DummyReader, TSerializer.StringWriter);

finalization
  vGlobalCustomTypeParsers.Free;

end.
