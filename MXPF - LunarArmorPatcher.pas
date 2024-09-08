unit UserScript;

uses 'lib\mxpf';

function Initialize: Integer;
var
  i, total: integer;
  e, slMasters, resistances: IInterface;
  armor, energy, weight, value, newWeight: float;
  torso, larm, rarm, lleg, rleg, damType: String;

const
  masterPlugin = fileByName('LunarFalloutOverhaul.esp');

begin
  // set MXPF options and initialize it
  DefaultOptionsMXPF;
  InitializeMXPF;
  SetExclusions('Fallout4.esm,DLCCoast.esm,DLCRobot.esm,DLCNukaWorld.esm,DLCWorkshop01.esm,DLCWorkshop02.esm,DLCWorkshop03.esm,LunarFalloutOverhaul.esp,Unofficial Fallout 4 Patch.esp');
  // select/create a new patch file that will be identified by its author field
  PatchFileByAuthor('LuanrArmorPatcher');
  
  slMasters := TStringList.Create;
  slMasters.Add('LunarFalloutOverhaul.esp');
  AddMastersToFile(mxPatchFile, slMasters, False);

  LoadRecords('ARMO');
  
  for i := MaxRecordIndex downto 0 do begin
    e := GetRecord(i);
    
    
    
    if (getElementEditValues(e, 'Record Header\record flags\Non-Playable') = '1') then removeRecord(i)
   
    else if (hasKeyword(e, 'ArmorTypeHelmet') or hasKeyword(e, 'ArmorTypeHat')) AND NOT HasAp(e, 'Ap_Legendary') then begin
    end
    //else if not (hasKeyword(e, 'ma_Railroad_ClothingArmor') OR HasAp(e, 'ap_Railroad_ClothingArmor')) then removeRecord(i);
    ;
  end;
  
  // then copy records to the patch file
  CopyRecordsToPatch;
  addMessage( IntToStr(MaxPatchRecordIndex) + ' Records copied to patch');
  
  // and set values on them
  for i := 0 to MaxPatchRecordIndex do begin
    process(GetPatchRecord(i));
  end;
  
  // call PrintMXPFReport for a report on successes and failures
  PrintMXPFReport;
  
  // always call FinalizeMXPF when done
  FinalizeMXPF;
end;
//============================================================================  
function Process(e: IInterface): integer;
var
  i: integer;
  appr: IInterface;
begin
	
    addMessage('----- Patching ' + EditorID(e) + '     ' + IntToHex(GetLoadOrderFormID(e), 8) + ' ---------------------------------------');
    
    if false then begin
      if hasKeyword(e, 'ArmorTypeHelmet') or hasKeyword(e, 'ArmorTypeHat') then begin
        if hasKeyword(e, 'ma_Railroad_ClothingArmor') or HasAp(e, 'ap_Railroad_ClothingArmor') then begin
          addMessage('Removing ma_Railroad_ClothingArmor from hat');
          removeRailroad(e);
        end;

        if NOT HasAp(e, 'Ap_Legendary') then begin
          if not Assigned(ElementBySignature(e, 'APPR')) then begin 
            Add(e, 'APPR', true);
            //appr := ElementAssign(ElementByPath(e, 'APPR'), HighInteger, nil, False);
            SetEditValue(ElementAssign(ElementByPath(e, 'APPR'), HighInteger, nil, False), '001E32C8');
          end
          else SetEditValue(ElementAssign(ElementByPath(e, 'APPR'), HighInteger, nil, False), '001E32C8');
        end;
        exit;
      end;
      
      if hasKeyword(e, 'ma_Railroad_ClothingArmor') and (NOT HasAp(e, 'ap_Railroad_ClothingArmor')) then begin 
          addMessage('Removing left behind ma_Railroad_ClothingArmor');
          removeRailroad(e);
          exit;
      end;
    end;



    if not hasBipedSlots(e) then begin
        addMessage('Removing railroad keywords from armor without all required body flags');
        removeRailroad(e);
        exit;        
    end;

    if shouldRecalcWeight(e) then setElementEditValues(e, 'DATA\weight', Round(getRecalcWeight(e)));

    
    if (StrToFloat(GetElementEditValues(e, 'DATA\weight')) > 20) and (NOT HasKeyword(e, 'ObjectTypeArmor')) then begin
        SetEditValue(ElementAssign(ElementByPath(e, 'KWDA'), HighInteger, nil, False), '000F4AE9');
        AddMessage('Added Keyword ObjectTypeArmor');
    end;
        
    if (not hasKeyword(e, 'ObjectTypeArmor') OR not hasAp(e, 'ap_armor_lining')) then begin 
        addMessage('Removing Armor Lining from Weaveable Clothing');
        removeArmorLining(e);
        exit;
    end;

    if hasKeyword(e, 'ma_Railroad_ClothingArmor') and (NOT HasAp(e, 'Ap_Legendary')) then begin
        SetEditValue(ElementAssign(ElementByPath(e, 'APPR'), HighInteger, nil, False), '001E32C8');
        AddMessage('Added Legendary AP');
    end;



end;

//============================================================================  
function hasBipedSlots(e: IInterface): boolean;
begin
    result := (
        (GetElementEditValues(e, 'BOD2\First Person Flags\33 - Body') = '1')
        and (GetElementEditValues(e, 'BOD2\First Person Flags\41 - [A] Torso') = '1')
        and (GetElementEditValues(e, 'BOD2\First Person Flags\42 - [A] L Arm') = '1')
        and (GetElementEditValues(e, 'BOD2\First Person Flags\43 - [A] R Arm') = '1')
        and (GetElementEditValues(e, 'BOD2\First Person Flags\44 - [A] L Leg') = '1')
        and (GetElementEditValues(e, 'BOD2\First Person Flags\45 - [A] R Leg') = '1')
    );
end;
//============================================================================  
function getRecalcWeight(e: IInterface): float;
var
    armor, energy, weight, value, newWeight: float;
    resistances, damType: IInterface;
    i: Integer;
begin
    armor := StrToInt(GetElementEditValues(e, 'FNAM\Armor Rating'));
	value := StrToInt(GetElementEditValues(e, 'DATA\value'));
	weight := StrToFloat(GetElementEditValues(e, 'DATA\weight'));

	resistances := ElementByPath(e, 'DAMA');
	
	for i := 0 to ElementCount(resistances)-1 do Begin
		damType := GetElementEditValues(ElementByIndex(resistances, i), 'Damage Type');
		if damType = 'dtEnergy [DMGT:00060A81]' then energy := GetElementEditValues(ElementByIndex(resistances, i), 'Value');
	end;

    result := 2 + Power(Armor/4, 1.3) + Power(Energy/4, 1.1);
end;
//============================================================================  
function shouldRecalcWeight(e: IInterface): boolean;
begin
    result := true;
    //result := Abs(StrToFloat(GetElementEditValues(e, 'DATA\weight'))-getRecalcWeight(e)) > (2 + GetElementEditValues(e, 'DATA\weight')/5);
end;
//============================================================================  
function HasAp(r: IInterface; keyword: string): boolean;
var
  i: integer;
  apprs: IwbElement;
  ap: String;
begin
  Result := false;
  apprs :=  ElementByPath(r, 'APPR');
  if apprs <> nil then for i := 0 to ElementCount(apprs)-1 do begin
      ap :=EditorID(LinksTo(ElementByIndex(apprs, i)));
      if ContainsText(ap, keyword) then begin
        Result := true;
        exit;
      end;
    end;
  
end;
//============================================================================

// remove railroad keywords
function removeRailroad(e: IInterface): boolean;
var
	kwda, appr: IInterface;
	n: integer;
begin
	kwda := ElementByPath(e, 'KWDA');
	for n := 0 to ElementCount(kwda) - 1 do begin
		//addMessage('looking at keyword ' +GetEditValue(ElementByIndex(kwda, n)));
		if Copy(GetEditValue(ElementByIndex(kwda, n)), 1, 25) = 'ma_Railroad_ClothingArmor' then	
			
		begin 
			//addMessage('Found the keyword, and trying to remove it');
			Remove(ElementByIndex(kwda, n));
		end;
	end;
	appr := ElementByPath(e, 'APPR');
	for n := 0 to ElementCount(appr) - 1 do begin
		if ContainsText(GetEditValue(ElementByIndex(appr, n)), 'Ap_Legendary') then Remove(ElementByIndex(appr, n));
        if ContainsText(GetEditValue(ElementByIndex(appr, n)), 'ap_Railroad_ClothingArmor') then Remove(ElementByIndex(appr, n));
	end;
	removeCombinationForRailroad(e)
end;

//============================================================================

// remove armor lining AP
function removeArmorLining(e: IInterface): boolean;
var
	kwda, appr: IInterface;
	n: integer;
  value: String;
begin
	kwda := ElementByPath(e, 'KWDA');
	for n := ElementCount(kwda) - 1 downTo 0 do begin
		value := GetEditValue(ElementByIndex(kwda, n));
    addMessage('looking at keyword ' +value);
		if Containstext(value, 'ma_armor_' ) then Remove(ElementByIndex(kwda, n));
	end;
	appr := ElementByPath(e, 'APPR');
	for n := 0 to ElementCount(appr) - 1 do begin
		//addMessage('looking at keyword ' +GetEditValue(ElementByIndex(kwda, n)));
		if ContainsText(GetEditValue(ElementByIndex(appr, n)), 'ap_armor_Lining') then Remove(ElementByIndex(appr, n));
        
	end;
	removeOmod(e, 'mod_armor_Lining_Null "No Misc" [OMOD:0018E59C]');
	
end;

//============================================================================

// remove resistances
function removeResistances(e: IInterface): boolean;
var
	resistances: IInterface;
	n, i, inum: integer;
	damType: string;
begin
	
	setElementEditValues(e, 'FNAM\Armor Rating', 0);

	resistances := ElementByPath(e, 'DAMA');
	inum := ElementCount(resistances);

	for i := 0 to inum do Begin
		damType := GetElementEditValues(ElementByIndex(resistances, i), 'Damage Type');
		if damType = 'dtEnergy [DMGT:00060A81]' then Remove(ElementByIndex(resistances, i));
	end;
end;

//============================================================================

// set use body slots
function SetUseBodySlots(e: IInterface): boolean;
var
	resistances: IInterface;
begin
	SetElementEditValues(e, 'BOD2\First Person Flags\41 - [A] Torso', 1);
	SetElementEditValues(e, 'BOD2\First Person Flags\42 - [A] L Arm', 1);
	SetElementEditValues(e, 'BOD2\First Person Flags\43 - [A] R Arm', 1);
	SetElementEditValues(e, 'BOD2\First Person Flags\44 - [A] L Leg', 1);
	SetElementEditValues(e, 'BOD2\First Person Flags\45 - [A] R Leg', 1);

end;

//============================================================================

// set use body slots
function removeOmod(e: IInterface; omod: string): boolean;
var
	templateList, template, obts, includesList, includes: IInterface;
	inum, i, jnum, j: integer;
begin
	templateList := ElementByPath(e, 'Object Template\Combinations');
	inum := ElementCount(templateList);
	for i := 0 to inum do Begin
		template := ElementByIndex(templateList, i);
		obts := ElementByPath(template, 'OBTS');
		includesList := ElementByPath(obts, 'Includes');
		jnum := ElementCount(includesList);
		for j := 0 to jnum do Begin
			includes := ElementByIndex(includesList, j);
			if GetElementEditValues(includes, 'Mod') = omod then Remove(ElementByIndex(includesList, j));
		end;
	end;
end;
//============================================================================
// Remove railroad template combination
function removeCombinationForRailroad(e: IInterface): boolean;
var
	templateList, template, obts, kwds: IInterface;
	inum, i, jnum, j: integer;
begin
	templateList := ElementByPath(e, 'Object Template\Combinations');
	inum := ElementCount(templateList);
	for i := 0 to inum do Begin
		template := ElementByIndex(templateList, i);
		obts := ElementByPath(template, 'OBTS');
		kwds := ElementByPath(obts, 'Keywords');
		if EditorID(LinksTo(ElementByIndex(kwds, 0))) = 'if_Railroad_ClothingArmor' then Remove(ElementByIndex(templateList, i));
	end;
end;

end.
