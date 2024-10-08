unit uMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Buttons,
  uCmdGenerator;

type

  { TForm1 }

  TForm1 = class(TForm)
    SelectDirectoryDialog1: TSelectDirectoryDialog;
    SetupButton: TButton;
    SelectGitProjectsPathButton: TButton;
    ChangeGitPathButton: TButton;
    GitProjectsPathEdit: TEdit;
    GitPathEdit: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    GitPathRefreshSpeedButton: TSpeedButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure GitPathRefreshSpeedButtonClick(Sender: TObject);
    procedure SelectGitProjectsPathButtonClick(Sender: TObject);
    procedure SetupButtonClick(Sender: TObject);
  private
    FCmd: TCmdGen;
    procedure RefreshGitPath;
  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

uses uGitInfo;

const FileName:string='gitpull2.cmd';

{ TForm1 }

procedure TForm1.SetupButtonClick(Sender: TObject);
var
  fullPath: string;
begin
  if DirectoryExists(GitProjectsPathEdit.Text) then
  begin
    fullPath:=IncludeTrailingPathDelimiter(GitProjectsPathEdit.Text) +
      FileName;
    try
    FCmd.SaveToFile(fullPath);
    MessageDlg('Файл скрипта автоматического pull успешно сохранён в папке ' +
      fullPath, TMsgDlgType.mtInformation, [mbOK], 0);
    except
      MessageDlg('Ошибка записи в файл ' + fullPath,
        TMsgDlgType.mtError, [mbOK], 0);
    end;
  end
  else
    ShowMessage('Не выбран путь к папке с проектами.');
end;

procedure TForm1.RefreshGitPath;
var
  gi: TGitInfo;
begin
  gi:= TGitInfo.Create;
  try
    GitPathEdit.Text:=(gi.GetGitPath);
  finally
    gi.Free;
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  FCmd:= TCmdGen.Create;
  FCmd.Add('echo off');
  FCmd.Add('');
  FCmd.Add('for /d %%i in (.\*) do (');
  FCmd.Add(' git -C %%i pull --progress -v --no-rebase -- "origin"');
  FCmd.Add('echo ---------------------------------------------------');
  FCmd.Add('echo .');
  FCmd.Add(')');
  FCmd.Add('');
  FCmd.Add('pause');

  RefreshGitPath;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FCmd);
end;

procedure TForm1.GitPathRefreshSpeedButtonClick(Sender: TObject);
begin
  RefreshGitPath;
end;

procedure TForm1.SelectGitProjectsPathButtonClick(Sender: TObject);
begin
  if SelectDirectoryDialog1.Execute then
    GitProjectsPathEdit.Text:= SelectDirectoryDialog1.FileName;
end;


end.

