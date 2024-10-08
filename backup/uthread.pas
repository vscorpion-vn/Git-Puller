unit uThread;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, WinTask, uTaskThrdAdditional;

type
  TSchTskMsgEvent=procedure(Sender: TObject; AMsg: string) of object;

  {$scopedEnums on}
  TTaskProcess=(Undefined, CreateNew, Update, Delete, Refresh);

  { TMissingTaskParamsException }

  { EMissingTaskParamsException }

  EMissingTaskParamsException=class(Exception)
  private
    FParamName: string;
  public
    // AParamDescription - Человеческое описание параметра, которое будет в сообщении.
    // Если AParamDescription='', то берётся значение из AParamName.
    constructor Create(const AParamName: string;
      AParamDescription: string); overload;
    constructor Create(const AMessage: string); overload;
    property ParamName: string read FParamName;
  end;

  { TSchTaskIdleParams }

  TSchTaskIdleParams=class
  private
    FIdleDuration: Cardinal;
    FRunOnlyIfIddle: boolean;
    FWaitTimeout: Cardinal;
    procedure SetIdleDuration(AValue: Cardinal);
    procedure SetWaitTimeout(AValue: Cardinal);
  public
    property RunOnlyIfIddle: boolean read FRunOnlyIfIddle
      write FRunOnlyIfIddle;
    // In seconds
    property IdleDuration: Cardinal read FIdleDuration write SetIdleDuration;
    // In seconds
    property WaitTimeout: Cardinal read FWaitTimeout write SetWaitTimeout;
  end;

  { TSchTskThread }

  TSchTskThread=class(TThread)
  private
    FIdleParams: TSchTaskIdleParams;
    //FInterval: Cardinal;
    FOnErrorMessage: TSchTskMsgEvent;
    FErrMsg: string;
    FTaskApp: string;
    FTaskDescription: string;
    FTaskFolderName: string;
    FTaskName: string;
    FTaskProcess: TTaskProcess;
    FTriggers: TTaskTriggerList;
    FWorkingDirectory: string;
    function ErrorMsg (const s : string; hr : HResult) : string;
    //procedure SetInterval(AValue: Cardinal);
    procedure SetTaskName(AValue: string);
    procedure WriteErrMsg (const s : string; hr : HResult); overload;
    procedure WriteErrMsg (const s : string); overload;
    procedure DoCallErrorMessage;
    // Если не указан какой-то необходимый параметр, то генерирует исключение.
    procedure CheckParams;
    // Запускается только из отдельного потока.
    procedure SetTaskOptions(ATask: TWinTask);
  protected
    procedure Execute; override;
  public
    constructor Create(CreateSuspended: boolean);
    destructor Destroy; override;
    property OnErrorMessage: TSchTskMsgEvent read FOnErrorMessage
      write FOnErrorMessage;
    procedure Refresh;
    property TaskName: string read FTaskName write SetTaskName;
    property TaskDescription: string read FTaskDescription
      write FTaskDescription;
    // Папка внутри планировщика.
    property TaskFolderName: string read FTaskFolderName write FTaskFolderName;
    //procedure UpdateTask;
    procedure CreateTask;
    procedure DeleteTask;
    property TaskApp: string read FTaskApp write FTaskApp;
    property WorkingDirectory: string read FWorkingDirectory
      write FWorkingDirectory;
    // Запускать задачу при простое компьютера.
    property IdleParams: TSchTaskIdleParams read FIdleParams;
    // Seconds
    //property Interval: Cardinal read FInterval write SetInterval;
    property Triggers: TTaskTriggerList read FTriggers;
    procedure SetTaskApp(ATaskApp: string; ASetWorkingDirectory: boolean);
  end;

implementation

uses DateUtils, ActiveX, TaskSchedApi //, WinTask
  {$IFDEF DEBUG}
  , dbugintf
  {$ENDIF}
  ;

{ TMissingTaskParamsException }

constructor EMissingTaskParamsException.Create(const AParamName: string;
  AParamDescription: string);
begin
  if AParamDescription='' then AParamDescription:=AParamName;
  FParamName:= AParamName;
  inherited Create(Format('Не задан параметр: %s.', [AParamDescription]));
end;

constructor EMissingTaskParamsException.Create(const AMessage: string);
begin
  inherited Create(AMessage);
end;

{ TSchTaskIdleParams }

procedure TSchTaskIdleParams.SetIdleDuration(AValue: Cardinal);
begin
  if FIdleDuration=AValue then Exit;
  FIdleDuration:=AValue;
end;

procedure TSchTaskIdleParams.SetWaitTimeout(AValue: Cardinal);
begin
  if FWaitTimeout=AValue then Exit;
  FWaitTimeout:=AValue;
end;

{ TSchTskThread }

function TSchTskThread.ErrorMsg(const s: string; hr: HResult): string;
begin
  Result:=s+Format(' - Returned HRESULT = $%.8x: %s',[hr,SysErrorMessage(hr)]);
end;

(*procedure TSchTskThread.SetInterval(AValue: Cardinal);
begin
  if FInterval=AValue then Exit;
  if AValue=0 then raise EArgumentException.Create('Интервал должен быть больше 0.');
  FInterval:=AValue;
end;*)

procedure TSchTskThread.SetTaskName(AValue: string);
begin
  if FTaskName=AValue then Exit;
  FTaskName:=AValue;
end;

procedure TSchTskThread.WriteErrMsg(const s: string; hr: HResult);
begin
  WriteErrMsg(ErrorMsg(s, hr));
end;

procedure TSchTskThread.WriteErrMsg(const s: string);
begin
  FErrMsg:= s;
  Synchronize(@DoCallErrorMessage);
end;

procedure TSchTskThread.DoCallErrorMessage;
begin
  if Assigned(FOnErrorMessage) then
    FOnErrorMessage(Self, FErrMsg);
end;

procedure TSchTskThread.CheckParams;
begin
  if (FTaskProcess <> TTaskProcess.Delete) and (FTaskApp='') then
    raise EMissingTaskParamsException.Create('FTaskApp',
      'Приложение для выполнения');
  if FTaskName='' then
    raise EMissingTaskParamsException.Create('TaskName',
      'Наименование задачи');
end;

procedure TSchTskThread.SetTaskOptions(ATask: TWinTask);
var
  td: TWinTask;
  i: Integer;
begin
  td:= ATask;
  with td do
  begin
    Description:=FTaskDescription;
    LogOnType:=ltToken;   // as current user
    Date:=Now;
    with TWinTaskExecAction(NewAction(taExec)) do
    begin
      WorkingDirectory:= FWorkingDirectory;
      ApplicationPath:=TaskApp;
      Arguments:='';
    end;
    with Settings do
    begin
      RunOnlyIfIdle:=IdleParams.RunOnlyIfIddle;
      IdleSettings.IdleDuration:=IdleParams.IdleDuration;  // seconds 600
      IdleSettings.WaitTimeout:=IdleParams.WaitTimeout; // 300
      DeleteExpiredTaskAfter:=0;
      // = -1 disabled
      // = 0  immediate
      // > 0  number of hours
    end;
    for i:= 0 to Self.Triggers.Count -1 do
    begin
      SendDebug(IntToStr(ord(ttTime)));
      SendDebug(IntToStr(ord(Self.Triggers[i].TriggerType)));
      with NewTrigger((*ttTime*)
        TWinTaskTriggerType((Self.Triggers[i].TriggerType))) do
      begin
        // добавлено
        //TriggerType:= TWinTaskTriggerType(ord(Self.Triggers[i].TriggerType));
        StartTime:=Now;
        EndTime:=Now+10;  // EncodeDateTime(2023,5,31,12,0,0,0);
        StopAtDurationEnd:=false;
        Interval:=Self.Triggers[i].Interval;  // 30 min = 1800 s
        Duration:=0;     // unlimited
        ExecutionTimeLimit:=0;
      end;
    end;
  end;
end;

procedure TSchTskThread.Execute;
//const
  //cTaskName = 'UpdateChecker';
  //cTaskApp = 'somefile.exe';
  //cTaskFolderName = 'GitNetvision';
var
  hr : HResult;
  WinTasks : TWinTaskScheduler;
  td : TWinTask;
  n : integer;
  tmpRes: boolean;
begin
  if FTaskProcess = TTaskProcess.Undefined then
    raise Exception.Create('Планировщик устанавливается через один из ' +
     'следующих методов: ' + sLineBreak + 'UpdateTask' + sLineBreak +
     'CreateTask' + sLineBreak + 'DeleteTask');
  CheckParams;
  WinTasks:= nil;
  // Initialize COM for COINIT_MULTITHREADED
  CoUninitialize;
  hr:=CoInitializeEx(nil,COINIT_MULTITHREADED);
  if SUCCEEDED(hr) then begin
    hr:=CreateWinTaskScheduler(WinTasks);
    if failed(hr) then begin
      if hr=NotAvailOnXp then begin
        WriteErrMsg ('Windows Task Scheduler 2.0 requires at least Windows Vista');
        end
      else WriteErrMsg ('Error initializing TWinTaskScheduler',hr);
      end
    else
      with WinTasks do
      begin
        //Check is folder excist
        n:= TaskFolder.IndexOfFolder(TaskFolderName);
        //SendDebug(IntToStr(n));
        if n < 0 then
        begin
          TaskFolder.CreateFolder(TaskFolderName);
        end;
        Path:= '\' + TaskFolderName;
          // Create new task
        n:=TaskFolder.IndexOfTask(TaskName);
        case FTaskProcess of
          TTaskProcess.CreateNew:
          begin // CreateNew
            if n<0 then
            begin
              td:=NewTask;
              SetTaskOptions(td);
              (*with td do
              begin
                Description:=FTaskDescription;
                LogOnType:=ltToken;   // as current user
                Date:=Now;
                with TWinTaskExecAction(NewAction(taExec)) do
                begin
                  WorkingDirectory:= FWorkingDirectory;
                  ApplicationPath:=TaskApp;
                  Arguments:='';
                end;
                with Settings do
                begin
                  RunOnlyIfIdle:=IdleParams.RunOnlyIfIddle;
                  IdleSettings.IdleDuration:=IdleParams.IdleDuration;  // seconds 600
                  IdleSettings.WaitTimeout:=IdleParams.WaitTimeout; // 300
                  DeleteExpiredTaskAfter:=0;
                   = -1 disabled
                   = 0  immediate
                   > 0  number of hours
                end;
                with NewTrigger(ttTime) do
                begin
                  StartTime:=Now;
                  EndTime:=Now+10;  // EncodeDateTime(2023,5,31,12,0,0,0);
                  StopAtDurationEnd:=false;
                  Interval:=Self.Interval;  // 30 min = 1800 s
                  Duration:=0;     // unlimited
                  ExecutionTimeLimit:=0;
                end;
              end;*)
              with TaskFolder do
                if RegisterTask(TaskName,td,'','')<0 then
                begin
                  WriteErrMsg('Could not create scheduled task!');
                  WriteErrMsg(SysErrorMessage(ResultCode(ErrorCode))+' - '+ErrorMessage);
                end
              else
                WriteErrMsg(Format('Задача "%s" успешно создана!',[TaskName]));
            end
            else
              WriteErrMsg (Format('Задача "%s" уже существует!',[TaskName]));
          end; // CreateNew
          TTaskProcess.Update:
            if n>=0 then
            begin
              td:= TaskFolder.Tasks[n].Definition;
              SetTaskOptions(td);
            end
            else
              WriteErrMsg(Format('Не найдена задача "%s" для редактирования!',
                [TaskName]));
          TTaskProcess.Delete:
            if n>=0 then
            begin
              tmpRes:= TaskFolder.DeleteTask(TaskName);
              if not tmpRes then
                WriteErrMsg(Format('Не удалось удалить задачу "%s"', [TaskName]));
            end
            else
              WriteErrMsg(Format('Не найдена задача "%s" для удаления!',
                [TaskName]));
          TTaskProcess.Refresh:
            if n>=0 then
            begin
              WinTasks.Refresh;
              td:= TaskFolder.Tasks[n].Definition;
              td.Refresh;
              TaskDescription:= td.Description;
              // Пока поддерживаем только одно действие.
              with td.Actions[0] do
              begin
                TaskApp:= ApplicationName;
                Self.WorkingDirectory:= WorkingDirectory;
              end;
              //with td.Triggers[0] do;
              //Self.Interval:= td.Interval;
            end
            else
              WriteErrMsg(Format('Не найдена задача "%s"!',
                [TaskName]));
        end;
      //end
      //else
        //WriteErrMsg(Format('Папка задач "%s" уже существует.', [cTaskFolderName]));
      Free;
    end;
  // Uninitialize COM
    CoUninitialize;
    end
  else WriteErrMsg ('Failed to run CoInitializeEx',hr);
  FTaskProcess:= TTaskProcess.Undefined;
end;

constructor TSchTskThread.Create(CreateSuspended: boolean);
begin
  inherited Create(CreateSuspended);
  FTaskProcess:= TTaskProcess.Undefined;
  FIdleParams:= TSchTaskIdleParams.Create;
  FTriggers:= TTaskTriggerList.Create(true);
  //Interval:=1800;
  FreeOnTerminate:= true;
end;

destructor TSchTskThread.Destroy;
begin
  {$IFDEF DEBUG}
  SendDebug('Destroy');
  {$ENDIF}
  FIdleParams.Free;
  FTriggers.Free;
  inherited Destroy;
end;

procedure TSchTskThread.Refresh;
begin
  FTaskProcess:= TTaskProcess.Refresh;
  Start;
end;

(*procedure TSchTskThread.UpdateTask;
begin
  FTaskProcess:= TTaskProcess.Update;
  Start;
end;*)

procedure TSchTskThread.CreateTask;
begin
  FTaskProcess:= TTaskProcess.CreateNew;
  Start;
end;

procedure TSchTskThread.DeleteTask;
begin
  FTaskProcess:= TTaskProcess.Delete;
  Start;
end;

procedure TSchTskThread.SetTaskApp(ATaskApp: string;
  ASetWorkingDirectory: boolean);
begin
  TaskApp:= ATaskApp;
  if ASetWorkingDirectory then
    WorkingDirectory:= ExtractFilePath(ATaskApp);
end;

end.

