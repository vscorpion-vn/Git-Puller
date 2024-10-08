unit uTaskThrdAdditional;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fgl;

type
  {$scopedEnums on}
  TTaskTriggerType = (ttEvent,ttTime,ttDaily,ttWeekly,ttMonthly,ttMonthlyDow,ttIdle,
    ttRegistration,ttBoot,ttLogon,ttSessionStateChange,ttCustom);

  { TTaskTrigger }

  TTaskTrigger=class
  private
    FInterval: Cardinal;
    FTriggerType: TTaskTriggerType;
    procedure SetInterval(AValue: Cardinal);
    procedure SetTriggerType(AValue: TTaskTriggerType);
  public
    constructor Create(ATaskTriggerType: TTaskTriggerType);
    property TriggerType: TTaskTriggerType read FTriggerType; //write SetTriggerType;
    property Interval: Cardinal read FInterval write SetInterval;
  end;

  TTaskTriggerList = specialize TFPGObjectList<TTaskTrigger>;

implementation

{ TTaskTrigger }

procedure TTaskTrigger.SetInterval(AValue: Cardinal);
begin
  if FInterval=AValue then Exit;
  FInterval:=AValue;
end;

procedure TTaskTrigger.SetTriggerType(AValue: TTaskTriggerType);
begin
  if FTriggerType=AValue then Exit;
  FTriggerType:=AValue;
end;

constructor TTaskTrigger.Create(ATaskTriggerType: TTaskTriggerType);
begin
  FTriggerType:= ATaskTriggerType;
  if ATaskTriggerType = TTaskTriggerType.ttTime then
    Interval:= 1800;
end;

end.

