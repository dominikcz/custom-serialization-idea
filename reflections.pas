unit reflections;

interface

uses
  System.Classes,
  System.SysUtils,
  System.StrUtils,
  System.TypInfo,
  System.Generics.Defaults,
  System.Generics.Collections,
  RTTI;

type
  TPropertyInfo = record
    PropType: string;
    PropTypeQualifiedName: string;
    PropLength: integer;
    TypeKind: System.TypInfo.TTypeKind;
  end;

  TPropertyInfoList = TDictionary<string, TPropertyInfo>;
  TPropertyValueList = TDictionary<string, Variant>;

  TReflection = class
  public
    class function GetProperties(AClass: TClass): TPropertyInfoList;
    class procedure SetPropertyValue(AObject: TObject;
      const APropertyName: string; const AValue: Variant);
    class function GetObjectProperties(AObject: TObject; AClass: TClass = nil): TPropertyValueList;
    class function GetObjectPropertiesAsString(AObject: TObject; AClass: TClass = nil; convertToUnderscore: boolean = true): string;
    class function GetPropertyValue(AObject: TObject; const APropertyName: string): Variant;
    class function GetPropertyObject(AObject: TObject; const APropertyName: string): TObject;
    class function GetEnumNames(AClass: TClass; APropertyName: string): TStringList; overload;
    class function GetEnumNames(ATypeInfo: PTypeInfo): TStringList; overload;
    class function GetTypeByName(AName: string): TRttiType;
    class function EnumToString(ATypeInfo: pointer; enumVal: integer): string;
    class function StringToEnum(ATypeInfo: pointer; enumName: string): integer;
    class function TryGetProperty(AObject: TObject; const AName: string; out AProperty: TRttiProperty): boolean; overload;
    class function TryGetProperty(ARttiType: TRttiType; const AName: string; out AProperty: TRttiProperty): boolean; overload;
    class function PropertyExists(ARttiType: TRttiType; const AName: string): boolean; overload;
    class function PropertyExists(AObject: TObject; const AName: string): boolean; overload;
    class function TryGetMethod(AObject: TObject; const AName: string; out AMethod: TRttiMethod): boolean; overload;
    class function TryGetMethod(ARttiType: TRttiType; const AName: string; out AMethod: TRttiMethod): boolean; overload;
    class function GetRttiType(AObject: TObject): TRttiType;
    class function TryGetField(AObject: TObject; const AName: string; out AField: TRttiField): boolean; overload;
    class function TryGetField(ARttiType: TRttiType; const AName: string; out AField: TRttiField): boolean; overload;
    class function GetDefaultVariant(AClassName: string ; APropertyName: string): Variant;
    class function GetObjectListItemClass(AObject: TObject): string;
    class function ContainsPropertyOrField(AObject: TObject; AName: string): boolean;
    class function GetSimpleConstructor(val: TRttiInstanceType; raiseExceptionIfNotFound: boolean = true): TRttiMethod;
    class function tryGetSimpleConstructor(val: TRttiInstanceType; out constructorMethod: TRttiMethod): Boolean;
    class function InvokeObjectListConstructor(val: TRttiInstanceType; ownsObjects: boolean): TObject;
    class function InvokeObjectDictionaryConstructor(val: TRttiInstanceType; Ownerships: TDictionaryOwnerships): TObject;
  end;


   TValueHelper = record helper for TValue
    private
      function GetRttiType: TRttiType;
    public
      function AsPointer: Pointer;
      function ToObject: TObject;
      function IsInterface: Boolean;
      property RttiType: TRttiType read GetRttiType;
      function IsCurrency: Boolean;
      function IsDate: Boolean;
      function IsDateTime: Boolean;
      function IsTime: Boolean;
   end;

implementation

uses
  variants;

var
  Context: TRttiContext;

class function TReflection.GetEnumNames(AClass: TClass;
  APropertyName: string): TStringList;
var
  P: TRttiProperty;
  i, enCount: integer;
begin
  Result := TStringList.Create;
  P := Context.GetType(AClass).GetProperty(APropertyName);
  enCount := GetTypeData(P.PropertyType.Handle).MaxValue;
  for i := 0 to enCount do
  begin
    Result.Add(GetEnumName(P.PropertyType.Handle, i));
  end;
end;


class function TReflection.ContainsPropertyOrField(AObject: TObject;
  AName: string): boolean;
var
  rttiType: TrttiType;
  rttiField: TrttiField;
  rttiProperty: TRttiProperty;
begin
  rttiType := Context.GetType(AObject.ClassType);
  rttiField := rttiType.GetField(AName);
  rttiProperty := rttiType.GetProperty(AName);
  Result := Assigned(rttiField) or Assigned(rttiProperty);
end;

class function TReflection.EnumToString(ATypeInfo: pointer; enumVal: integer): string;
begin
  try
    Result := GetEnumName(ATypeInfo, enumVal);
  except
    Result := '';
  end;
end;

class function TReflection.GetDefaultVariant(AClassName,
  APropertyName: string): Variant;
var
  rttiType: TrttiType;
  rttiField: TrttiField;
  rttiProperty: TRttiProperty;
  val: tValue;
begin
 result  := null;
 rttiType := GetTypeByName(AClassName);
 if rttiType = nil then
  exit;
 rttiField := rttiType.GetField(APropertyName);
 rttiProperty := rttiType.GetProperty(APropertyName);
 if rttiField <> nil then
  TValue.Make(nil, rttiField.FieldType.Handle, val)
 else if rttiProperty <> nil then
  TValue.Make(nil, rttiProperty.PropertyType.Handle, val);



 result := val.AsVariant;


end;

class function TReflection.GetEnumNames(ATypeInfo: PTypeInfo): TStringList;
var
  i, enCount: integer;
begin
  Result := TStringList.Create;
  enCount := GetTypeData(ATypeInfo).MaxValue;
  for i := 0 to enCount do
  begin
    Result.Add(GetEnumName(ATypeInfo, i));
  end;
end;

class function TReflection.GetObjectListItemClass(AObject: TObject): string;
var
  LMethod: TRttiMethod;
begin
  if{ TReflection.PropertyExists(aObject, 'OwnsObject') and }TReflection.TryGetMethod(aObject, 'Add', LMethod) then
  begin
    Result :=  LMethod.GetParameters[0].ParamType.asInstance.MetaclassType.QualifiedClassName;
//    LType := LMethod.GetParameters[0].ParamType.as;
//    &type := LType.AsInstance.MetaclassType;
//    repeat
//      listItem := &type.Create;
//      aFrom := mORMot.JsonToObject(listItem, aFrom, aValid, &type);
//      LMethod.Invoke(aObject, [TValue.From(listItem)]);
//    until (aFrom = nil) or (aFrom^ = ']');
//    exit;
  end;
end;

class function TReflection.GetObjectProperties(AObject: TObject; AClass: TClass)
  : TPropertyValueList;
var
  P: TRttiProperty;
  F: TRttiField;
  enumStr: String;
  props: TArray<TRttiProperty>;
  fields: TArray<TRttiField>;
begin
  Result := TPropertyValueList.Create;
  if AClass <> nil then
  begin
    props  := Context.GetType(AClass).GetProperties;
    fields := Context.GetType(AClass).GetFields;
  end else
  begin
    props  := Context.GetType(AObject.ClassType).GetProperties;
    fields := Context.GetType(AObject.ClassType).GetFields
  end;
  for P in props do
  begin
    if P.Visibility >= mvPublic then
    begin
      if P.PropertyType.TypeKind =  tkClass then
        continue
      else if P.PropertyType.TypeKind <> tkEnumeration then
        try
          Result.Add(P.Name, P.GetValue(pointer(AObject)).AsVariant)
        except
          {$IFDEF DEBUG}
          raise Exception.Create('TReflection.GetObjectProperties: P.Name['+P.Name+'] AObject.ClassType['+AObject.ClassType.ClassName+']');
          {$ELSE DEBUG}
          raise
          {$ENDIF}
        end
      else
      begin
        try
          enumStr := P.GetValue(pointer(AObject)).ToString;
          Result.Add(P.Name, GetEnumValue(P.PropertyType.Handle, enumStr));
        except
          {$IFDEF DEBUG}
          raise Exception.Create('TReflection.GetObjectProperties: P.Name['+P.Name+'] AObject.ClassType['+AObject.ClassType.ClassName+']');
          {$ELSE DEBUG}
          raise
          {$ENDIF}
        end;
      end;
    end;
  end;
  for F in fields do
  begin
    if F.Visibility >= mvPublic then
    begin
      if F.FieldType.TypeKind =  tkClass then
        continue
      else if F.FieldType.TypeKind <> tkEnumeration then
        try
          Result.Add(F.Name, F.GetValue(pointer(AObject)).AsVariant)
        except
          {$IFDEF DEBUG}
          raise Exception.Create('TReflection.GetObjectProperties: F.Name['+F.Name+'] AObject.ClassType['+AObject.ClassType.ClassName+']');
          {$ELSE DEBUG}
          raise
          {$ENDIF}
        end
      else
      begin
        try
          enumStr := F.GetValue(pointer(AObject)).ToString;
          Result.Add(F.Name, GetEnumValue(F.FieldType.Handle, enumStr));
        except
          {$IFDEF DEBUG}
          raise Exception.Create('TReflection.GetObjectProperties: F.Name['+F.Name+'] AObject.ClassType['+AObject.ClassType.ClassName+']');
          {$ELSE DEBUG}
          raise
          {$ENDIF}
        end;
      end;
    end;
  end;
end;

class function TReflection.GetObjectPropertiesAsString(AObject: TObject; AClass: TClass = nil; convertToUnderscore: boolean = true): string;
var
  tmp: TPropertyValueList;
  skey, key: string;
  v: variant;
begin
  Result := '';
  tmp := GetObjectProperties(AObject, AClass);
  if tmp = nil then
    exit;
  for key in tmp.Keys do
  begin
    v := tmp.Items[key];
    skey := key;
    result := result + skey + '=' + VarToStr(v) + ';';
  end;
end;

class function TReflection.GetProperties(AClass: TClass): TPropertyInfoList;
var
  P: TRttiProperty;
  F: TRttiField;
  LPropertyInfo: TPropertyInfo;
  sTypeName: string;
begin
  Result := TPropertyInfoList.Create;
  for P in Context.GetType(AClass).GetProperties do
  begin
    if P.Visibility >= mvPublic then
    begin
      try
        LPropertyInfo.PropLength := P.PropertyType.TypeSize;
        LPropertyInfo.PropType := P.PropertyType.Name;
        LPropertyInfo.PropTypeQualifiedName := P.PropertyType.QualifiedName;
        LPropertyInfo.TypeKind := P.PropertyType.TypeKind;
        Result.Add(P.Name, LPropertyInfo);
      except
        {$IFDEF DEBUG}
        if P.PropertyType = nil then
          sTypeName := 'nil'
        else
          sTypeName := P.PropertyType.Name;

        raise Exception.CreateFmt('TReflection.GetProperties: P.Name=%s, P.PropertyType=%s, AClass.ClassType=%s', [P.Name, sTypeName, AClass.ClassName]);
        {$ELSE DEBUG}
        raise
        {$ENDIF}
      end;
    end;
  end;
  for F in Context.GetType(AClass).GetFields do
  begin
    if F.Visibility >= mvPublic then
    begin
      try
        LPropertyInfo.PropLength := F.FieldType.TypeSize;
        LPropertyInfo.PropType := F.FieldType.Name;
        LPropertyInfo.PropTypeQualifiedName := F.FieldType.QualifiedName;
        LPropertyInfo.TypeKind := F.FieldType.TypeKind;
        Result.Add(F.Name, LPropertyInfo);
      except
        {$IFDEF DEBUG}
        if f.FieldType = nil then
          sTypeName := 'nil'
        else
          sTypeName := F.FieldType.Name;

        raise Exception.CreateFmt('TReflection.GetProperties: F.Name=%s, F.FieldType=%s, AClass.ClassType=%s', [F.Name, sTypeName, AClass.ClassName]);
        {$ELSE DEBUG}
        raise
        {$ENDIF}
      end;
    end;
  end;
end;

class function TReflection.GetPropertyObject(AObject: TObject;
  const APropertyName: string): TObject;
var
  prop: TRttiProperty;
  field: TRttiField;
  val: TValue;
begin
  Result := nil;
  prop := Context.GetType(AObject.ClassType).GetProperty(APropertyName);
  if prop <> nil then
  begin
    if prop.PropertyType.TypeKind = tkClass then
      Result := prop.GetValue(pointer(AObject)).AsObject;
  end
  else
  begin
    field := Context.GetType(AObject.ClassType).GetField(APropertyName);
    if (field <> nil) and (field.FieldType.TypeKind = tkClass) then
    begin
      Result := field.GetValue(pointer(AObject)).AsObject;
    end;
  end;
end;

class function TReflection.GetPropertyValue(AObject: TObject;
  const APropertyName: string): Variant;
var
  P: TRttiProperty;
  enumStr: String;
  rec: TRttiRecordType;
  field: TRttiField;
  val: TValue;
begin
  Result := 0;
  P := Context.GetType(AObject.ClassType).GetProperty(APropertyName);
  if P <> nil then
  begin
    case P.PropertyType.TypeKind of
      System.TypInfo.TTypeKind.tkRecord:
        begin
          val := P.GetValue(pointer(AObject));
          rec := Context.GetType(P.GetValue(pointer(AObject)).TypeInfo).AsRecord;
          for field in rec.GetFields do
          begin
            Result := field.GetValue(val.GetReferenceToRawData).ToString;
          end;
        end;
      System.TypInfo.TTypeKind.tkEnumeration:
        begin
          enumStr := P.GetValue(pointer(AObject)).ToString;
          Result := GetEnumValue(P.PropertyType.Handle, enumStr);
        end;
    else
      begin
        Result := P.GetValue(pointer(AObject)).AsVariant;
      end;
    end;
  end
  else
  begin
    field := Context.GetType(AObject.ClassType).GetField(APropertyName);
    if field <> nil then
    begin
      case field.FieldType.TypeKind of
        System.TypInfo.TTypeKind.tkRecord:
          begin
            val := field.GetValue(pointer(AObject));
            rec := Context.GetType(field.GetValue(pointer(AObject)).TypeInfo).AsRecord;
            for field in rec.GetFields do
            begin
              Result := field.GetValue(val.GetReferenceToRawData).ToString;
            end;
          end;
        System.TypInfo.TTypeKind.tkEnumeration:
          begin
            enumStr := field.GetValue(pointer(AObject)).ToString;
            Result := GetEnumValue(field.FieldType.Handle, enumStr);
          end;
        else
          Result := field.GetValue(pointer(AObject)).AsVariant;
      end;
    end;
  end;
end;

class function TReflection.GetRttiType(AObject: TObject): TRttiType;
begin
  Result := Context.GetType(AObject.ClassType);
end;

class function TReflection.GetSimpleConstructor(val: TRttiInstanceType; raiseExceptionIfNotFound: boolean = true): TRttiMethod;
var
  i, j: integer;
  method: TRttiMethod;
  parmeter: TRttiParameter;
  useTObjectContructor: boolean;
begin
  Result := nil;
  i := 1;
  useTObjectContructor := true;

  // UcLog.Add(100, 0, 'constructor for: ' + val.MetaclassType.ClassName);
  try
    for method in val.GetDeclaredMethods do
    begin
      if not method.IsConstructor then
        continue;
      // useTObjectContructor := false;
      j := 1;
      // UcLog.Add(100, 0, 'constructor nr: ' + IntToStr(i));
      for parmeter in method.GetParameters do
      begin
        // UcLog.Add(100, 0,'   ' + parmeter.Name + ': ' + parmeter.ParamType.QualifiedName);
        inc(j);
      end;
      if (method.IsConstructor) and (length(method.GetParameters) = 0) then
        exit(method);
      inc(i)
    end;

    if useTObjectContructor then
    begin
      for method in val.GetMethods('Create') do
      begin
        if (method.IsConstructor) and (length(method.GetParameters) = 0) then
          exit(method);
      end;
    end;
  finally
    if (Result = nil) and raiseExceptionIfNotFound then
      raise EInsufficientRTTI.CreateFmt('No simple constructor available for class %s ',
        [val.MetaclassType.ClassName]);
  end;
end;


class function TReflection.GetTypeByName(AName: string): TRttiType;
begin
  Result := Context.FindType(AName);
end;

class function TReflection.InvokeObjectDictionaryConstructor(
  val: TRttiInstanceType; Ownerships: TDictionaryOwnerships): TObject;
var
  method: TRttiMethod;
  parameters: TArray<TRttiParameter>;
begin
  result := nil;
  for method in val.GetMethods('Create') do
  begin
    if (method.IsConstructor) then
    begin
      parameters := method.GetParameters;
      if (length(parameters) = 2) and (parameters[0].Name = 'Ownerships') and (parameters[1].Name = 'ACapacity') then
      begin
        //TODO: zrobiæ TValue z ownerShips
       // Result := method.Invoke(val.MetaclassType, [doOwnsKeys, 0]).AsObject;
        break;
      end;
    end;
  end;
end;

class function TReflection.InvokeObjectListConstructor(val: TRttiInstanceType; ownsObjects: boolean): TObject;
var
  method: TRttiMethod;
  parameters: TArray<TRttiParameter>;
begin
  result := nil;
  for method in val.GetMethods('Create') do
  begin
    if (method.IsConstructor) then
    begin
      parameters := method.GetParameters;
      if (length(parameters) = 1) and (parameters[0].Name = 'AOwnsObjects') then
      begin
        Result := method.Invoke(val.MetaclassType, [ownsObjects]).AsObject;
        break;
      end;
    end;
  end;
end;

class function TReflection.PropertyExists(AObject: TObject; const AName: string): Boolean;
begin
  if not Assigned(AObject) then
  begin
    Result := false;
    exit;
  end;
  result := Context.GetType(AObject.ClassType).GetProperty(AName) <> nil;
end;

class function TReflection.PropertyExists(ARttiType: TRttiType; const AName: string): Boolean;
begin
  result := ARttiType.GetProperty(AName) <> nil;
end;

class procedure TReflection.SetPropertyValue(AObject: TObject;
  const APropertyName: string; const AValue: Variant);
var
  P: TRttiProperty;
  F: TRttiField;
  AVal: TValue;
  debugValue, strVal: string;
  lDate: tDateTime;
  varT: word;
  lOdometerReq: boolean;
  enumVal: integer;
begin
  AVal := TValue.FromVariant(AValue);
  P := Context.GetType(AObject.ClassType).GetProperty(APropertyName);
  if P <> nil then
  begin
    if not P.IsWritable then
      exit;
    try
      if P.PropertyType.TypeKind = tkEnumeration then
      begin
        if VarIsStr(AValue) then
        begin
          enumVal := GetEnumValue(P.PropertyType.Handle, AValue);
          TValue.Make(enumVal, P.PropertyType.Handle, AVal);
        end
        else
          TValue.Make(AValue, P.PropertyType.Handle, AVal);
      end
      else if (P.PropertyType.TypeKind = tkString) or (P.PropertyType.TypeKind = tkUString) then
        begin
          if VarIsNull(AValue) then
            strVal := ''
          else
            strVal := trim(AValue);
          AVal := TValue.From(strVal);
        end ;
      P.SetValue(pointer(AObject), AVal);
    except
      on e: exception do
      begin
        if VarIsNull(AValue) then
          debugValue := 'Null'
        else
          debugValue := AValue;
        raise Exception.CreateFmt('Could not assign value: %s to property %s.%s of type %s',
          [debugValue, AObject.ClassName, APropertyName, P.PropertyType.ToString] );
      end;
    end;
  end
  else
  begin
    F := Context.GetType(AObject.ClassType).GetField(APropertyName);
    if F <> nil then
    begin
      try
        if F.FieldType.TypeKind = tkEnumeration then
        begin
          if VarIsStr(AValue) then
          begin
            enumVal := GetEnumValue(F.FieldType.Handle, AValue);
            TValue.Make(enumVal, F.FieldType.Handle, AVal);
          end
          else
            TValue.Make(AValue, F.FieldType.Handle, AVal);
        end
        else if (F.FieldType.TypeKind = tkString) or (F.FieldType.TypeKind = tkUString) then
        begin
          if VarIsNull(AValue) then
            strVal := ''
          else
            strVal := trim(AValue);
          AVal := TValue.From(strVal);
        end
        else if (F.FieldType.TypeKind = tkInteger) and VarIsType(AValue,varBoolean) then
        begin
          lOdometerReq := VarAsType(AValue, varBoolean);
          AVal := TValue.FromVariant(Ord(lOdometerReq));
        end
        else if (F.FieldType.TypeKind = tkFloat)  then
        begin
          varT := VarType(AValue);
          if (VarT = varUString) or (varT = varString) then
          begin
            lDate := StrToDateTime(AValue);
            AVal := TValue.FromVariant(VarFromDateTime(lDate));
          end;
        end;

      //  F.FieldType.TypeKind = tk
//        AVal := TValue.FromVariant((VarAsType(AValue)))
        F.SetValue(pointer(AObject), AVal);
      except
        on e: exception do
        begin
          if VarIsNull(AValue) then
            debugValue := 'Null'
          else
            debugValue := AValue;
          raise Exception.CreateFmt('Could not assign value: %s to field %s.%s of type %s',
            [debugValue, AObject.ClassName, APropertyName, F.FieldType.ToString] );
        end;
      end;
    end;
  end;
end;

class function TReflection.StringToEnum(ATypeInfo: pointer;
  enumName: string): integer;
begin
  Result := GetEnumValue(ATypeInfo, enumName);
end;

class function TReflection.TryGetMethod(AObject: TObject; const AName: string;
  out AMethod: TRttiMethod): Boolean;
begin
  if not Assigned(AObject) then
  begin
    Result := false;
    exit;
  end;
  AMethod :=  Context.GetType(AObject.ClassType).GetMethod(AName);
  Result := Assigned(AMethod);
end;

class function TReflection.TryGetField(AObject: TObject; const AName: string;
  out AField: TRttiField): Boolean;
begin
  if not Assigned(AObject) then
  begin
    Result := false;
    exit;
  end;
  AField :=  Context.GetType(AObject.ClassType).GetField(AName);
  Result := Assigned(AField);
end;

class function TReflection.TryGetField(ARttiType: TRttiType;
  const AName: string; out AField: TRttiField): Boolean;
begin
  AField := ARttiType.GetField(AName);
  Result := Assigned(AField);
end;

class function TReflection.TryGetMethod(ARttiType: TRttiType;
  const AName: string; out AMethod: TRttiMethod): Boolean;
begin
   AMethod := ARttiType.GetMethod(AName);
   Result := Assigned(AMethod);
end;

class function TReflection.TryGetProperty(ARttiType: TRttiType;
  const AName: string; out AProperty: TRttiProperty): Boolean;
begin
  AProperty := ARttiType.GetProperty(AName);
  Result := Assigned(AProperty);
end;

class function TReflection.tryGetSimpleConstructor(val: TRttiInstanceType; out constructorMethod: TRttiMethod): boolean;
begin
  constructorMethod := GetSimpleConstructor(val, false);
  Result := Assigned(constructorMethod);
end;

class function TReflection.TryGetProperty(AObject: TObject; const AName: string;
  out AProperty: TRttiProperty): Boolean;
begin
  if not Assigned(AObject) then
  begin
    Result := false;
    exit;
  end;
  AProperty :=  Context.GetType(AObject.ClassType).GetProperty(AName);
  Result := Assigned(AProperty);
end;

{ TValueHelper }

function TValueHelper.AsPointer: Pointer;
begin
  if Kind in [tkClass, tkInterface] then
    Result := ToObject
  else
    Result := GetReferenceToRawData;
end;

function TValueHelper.GetRttiType: TRttiType;
begin
  Result := Context.GetType(TypeInfo);
end;

function TValueHelper.IsCurrency: Boolean;
begin
  Result := false;
  //TODO: dokonczyc
end;

function TValueHelper.IsDate: Boolean;
begin
  Result := Assigned(TypeInfo) and (TypeInfo.Kind = tkFloat);
end;

function TValueHelper.IsDateTime: Boolean;
begin
   Result := Assigned(TypeInfo) and (TypeInfo.Kind = tkFloat);
end;

function TValueHelper.IsInterface: Boolean;
begin
  Result := Assigned(TypeInfo) and (TypeInfo.Kind = tkInterface);
end;

function TValueHelper.IsTime: Boolean;
begin
  Result := Assigned(TypeInfo) and (TypeInfo.Kind = tkFloat);  //TODO: dokonczyc
end;

function TValueHelper.ToObject: TObject;
begin
  if IsInterface then
    Result := AsInterface as TObject
  else
    Result := AsObject;
end;

initialization
  Context := TRttiContext.Create;

finalization
  Context.Free;
end.
