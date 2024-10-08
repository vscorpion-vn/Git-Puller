unit uGitInfo;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

type

  { TGitInfo }

  TGitInfo=class
  public
    function GetGitPath: string;
  end;

implementation

uses registry;

{ TGitInfo }

function TGitInfo.GetGitPath: string;
var
  reg: TRegistry;
  gitpath: string;
const
  regPath: string = '\SOFTWARE\GitForWindows\';
  regKey: string = 'InstallPath';
begin
  gitpath:='';
  reg:= TRegistry.Create();
  try
     reg.RootKey:= HKEY_CURRENT_USER;
     if reg.OpenKeyReadOnly(regPath) then
        gitpath:= reg.ReadString(regKey)
     else
     begin
       reg.RootKey:= HKEY_LOCAL_MACHINE;
       if reg.OpenKeyReadOnly(regPath) then
        gitpath:= reg.ReadString(regKey)
     end;
  finally
    reg.Free;
  end;
  Result:= gitpath;
end;

end.

