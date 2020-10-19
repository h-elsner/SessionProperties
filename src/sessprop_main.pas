        {********************************************************}
        {                                                        }
        {                SessionPropertyTool                     }
        {                                                        }
        {         Copyright (c) 2020    Helmut Elsner            }
        {                                                        }
        {       Compiler: FPC 3.0.4   /    Lazarus 2.0.8         }
        {                                                        }
        { Pascal programmers tend to plan ahead, they think      }
        { before they type. We type a lot because of Pascal      }
        { verboseness, but usually our code is right from the    }
        { start. We end up typing less because we fix less bugs. }
        {           [Jorge Aldo G. de F. Junior]                 }
        {********************************************************}

(*
This source is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your option)
any later version.

This code is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
details.

A copy of the GNU General Public License is available on the World Wide Web
at <http://www.gnu.org/copyleft/gpl.html>. You can also obtain it by writing
to the Free Software Foundation, Inc., 51 Franklin Street - Fifth Floor,
Boston, MA 02110-1335, USA.

================================================================================
Brief description:

Lazarus-IDE has Session Properties at the main form to store program settings for next start.

But if you try to rename objects that are already assigned to Session Properties,
these items will not be renamed.

This means, assignmet is lost and program settings are not kept.
Relicts with old object names are left in XML files. If many values are stored
in larger projects, it quickly becomes confusing. Usually, this behaviour
will be found only with intensive program tests.

To overcome this situation this tool will find orphaned items in
Session Properties, makes it easier to correct Session Properties and
avoid incomplete program settings.
================================================================================

Status Bar: Index          0           1          2              3
--------------------+-----------+-------------+-----------+-------------
 Session Properties: # lines in  # properties  # hits      Text messages
 Objects list:       # lines in  # objects     n/a         Text messages
 XML check           # lines in  # XML items   # unused    Text messages


gridResult.Tag: 0..Property list
                1..Object list
                2..XML list
StatusBar.Tag: Index of icon in Panel2


ToDo: XML handling! Multiline XML not recognized if lists are stored too.

2020-10-05   Idea and functionality
2020-10-06   Improved GUI, finalization and languages
2020-10-14   Check XML Settings, delete unused
2020-10-15   Main Menu and ActionList added

==============================================================================*)

unit SessProp_main;                              {SessionProperty tool: find orphaned items}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, Buttons,
  Grids, ComCtrls, StdCtrls, XMLPropStorage, Menus, ActnList,
  laz2_DOM, laz2_xmlread;

type                                             {TMain}
  TMain = class(TForm)
    actClose: TAction;
    actSaveCSV: TAction;
    actXMLcheck: TAction;
    actWaisen: TAction;
    ActionList: TActionList;
    btnXMLcheck: TBitBtn;
    btnClose: TBitBtn;
    btnWaisen: TBitBtn;
    cbFilter: TCheckBox;
    cbDelete: TCheckBox;
    ImageList: TImageList;
    MainMenu: TMainMenu;
    mnClose: TMenuItem;
    N2: TMenuItem;
    mnSave: TMenuItem;
    N1: TMenuItem;
    mnWaisen: TMenuItem;
    mnXMLcheck: TMenuItem;
    mnFunction: TMenuItem;
    mnSaveCSV: TMenuItem;
    OpenDialog: TOpenDialog;
    pnlHeader: TPanel;
    PopupMenuTabelle: TPopupMenu;
    SaveDialog: TSaveDialog;
    StatusBar: TStatusBar;
    gridResults: TStringGrid;
    XMLPropStorage1: TXMLPropStorage;
    procedure actCloseExecute(Sender: TObject);
    procedure actSaveCSVExecute(Sender: TObject);
    procedure actWaisenExecute(Sender: TObject);
    procedure actXMLcheckExecute(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure gridResultsPrepareCanvas(sender: TObject; aCol, aRow: Integer;
                                       aState: TGridDrawState);
    procedure gridResultsResize(Sender: TObject);
    procedure StatusBarDrawPanel(StatusB: TStatusBar; Panel: TStatusPanel;
                                 const Rect: TRect);
  private
    procedure SetStatusbar(num: integer);          {Reset StatusBar}
    procedure WaisenSuchen(fn: string);            {Search orphaned items}
    procedure XMLsuchen(fn: string);               {Open XML to check against lfm}
    procedure XML_read(fn: string; alist: TStringList);
    procedure ShowObjectList(list: TStringList);   {Object list to result table}
  public
  end;

var
  Main: TMain;

const
  sep=';';                                         {SessionProperty separator,also CSV seperator}
  pkt='.';                                         {Property-value separator}
  dpkt=':';                                        {Object separator}
  strID='''';                                      {String identificator in lfm}
  qchar='"';                                       {String identificator in xml}
  xsep='_';                                        {Object separator in XML}
  endm='/';                                        {End XML node}
  gleich='=';

  backup='.bak';
  tab1=' ';
  tabn='   ';

  defRows=5;                                       {Number lines for empty table}
  clHighLighted=$005B5BFF;                         {Indicate orphaned items}
  sumode=5;                                        {Show up mode (options look & feel):
                                                      bit0..Color mode on   1
                                                      bit1..Only last cell  2
                                                      bit2..Column width    4  }
{Keywords}
  kwObject='object';
  kwSessProp='SessionProperties';


implementation

{$R *.lfm}
{$I strings_de.inc}                                {German GUI}
{.$I strings_en.inc}                               {English GUI}

                                                   {TMain: main (and only) form}
procedure TMain.FormCreate(Sender: TObject);       {Initiate all and set defaults}
begin
  Caption:=rsProgName;                             {Assign text values}
  actWaisen.Caption:=capWaisen;
  actWaisen.Hint:=hntWaisen;
  actXMLcheck.Caption:=capXMLcheck;
  actXMLcheck.Hint:=hntXMLcheck;
  actClose.Caption:=capClose;
  actClose.Hint:=hntClose;
  cbFilter.Caption:=capFilter;
  cbFilter.Hint:=hntFilter;
  cbDelete.Caption:=capDelete;                     {Delete unused items}
  cbDelete.Hint:=hntDelete;
  StatusBar.Hint:=hntStatus;
  StatusBar.Tag:=-1;                               {No icon shown}
  OpenDialog.Filter:=rsExtFilter;                  {Filter file type}
  actSaveCSV.Caption:=capSaveCSV;                  {Popup menu Save as CSV}
  actSaveCSV.Hint:=ttSaveDialog;
  mnSaveCSV.Enabled:=false;                        {Disable Save menu (default)}
  mnFunction.Caption:=capFunc;
  gridResults.RowCount:=defRows;                   {Show empty table}
  gridResults.Rows[0].Delimiter:=sep;
  gridResults.Rows[0].DelimitedText:=rsHeader;
end;

procedure ShowSearchResult(grid: TStringGrid; pos: integer; w1, w2: string;
                           only, orph: boolean);   {Fill Result table}
begin
  if only then begin                               {Show only orphaned}
    if orph then begin
      grid.RowCount:=grid.RowCount+1;              {New line added, fill it}
      grid.Cells[0, grid.RowCount-1]:=w1;
      grid.Cells[1, grid.RowCount-1]:=w2;
      grid.Cells[2, grid.RowCount-1]:=rsVerwaist;
    end;
  end else begin                                   {Show all items}
    grid.Cells[0, pos]:=w1;
    grid.Cells[1, pos]:=w2;
    if orph then
      grid.Cells[2, pos]:=rsVerwaist;
  end;
end;

                                                   {Find position SessionProperties in lfm}
function findProperties(list, outlist: TStringList): integer;
var i, p: integer;                                 {outlist: list of objects in lfm}
begin
  result:=-1;
  outlist.Clear;
  for i:=0 to list.Count-1 do begin
    p:=pos(kwSessProp, list[i]);                   {Position SessionProperty}
    if p>0 then begin                              {Clean property string}
      list[i]:=list[i].Split([strID])[1];
      if length(list[i])>2 then                    {Minimum a.b}
        result:=i;                                 {Send line No SessionProperties in lfm}
    end;

    p:=pos(kwObject, list[i]);                     {Create list of all objects in lfm}
    if p>0 then
      outlist.Add(trim(StringReplace(list[i],
    kwObject, '', [rfReplaceAll, rfIgnoreCase])));
  end;
end;

procedure CleanObj(list: TStringList);             {Remove object type}
var i: integer;
begin
  for i:=0 to list.Count-1 do begin
    list[i]:=trim(list[i].Split([dpkt])[0]);       {only pure object names in list}
  end;
end;

procedure TMain.gridResultsPrepareCanvas(sender: TObject; aCol, aRow: Integer;
                                         aState: TGridDrawState);
begin                                              {Highlight lines with orphaned Properties}
  if ((sumode and 1)=1) and                        {feature allowed}
     (aRow>0) and                                  {Ignore title}
     (gridResults.Cells[2, aRow]=rsVerwaist) and   {Orphaned items only}
     ((aCol=2) or ((sumode and 2)<>2)) then        {Only last cell colored, optional}
    gridResults.Canvas.Brush.Color:=clHighLighted;
end;

procedure TMain.gridResultsResize(Sender: TObject); {Better looking columns}
const
  SBarWidth = 22;
begin
  if (sumode and 4)>0 then                         {Feature allowed}
    with gridResults do begin
      ColWidths[1]:=(Width - ColWidths[3]) div 2 - SBarWidth;
      ColWidths[0]:=ColWidths[1];
    end;
end;

procedure TMain.StatusBarDrawPanel(StatusB: TStatusBar; Panel: TStatusPanel;
                                   const Rect: TRect);
begin                                              {Display icon [pidx] from ImageList}
  if Panel.Index=2 then begin                      {Only in Panel 2}
    ImageList.Draw(StatusB.Canvas, Rect.Left, Rect.Top, StatusBar.Tag);
    StatusB.Canvas.Brush.Color:=StatusBar.Color;   {Background for text}
    StatusB.Canvas.TextOut(Rect.Left+ImageList.Width+4, Rect.Top, Panel.Text);
  end;
end;

procedure TMain.ShowObjectList(list: TStringList); {Object list to result table}
var i: integer;
begin
  StatusBar.Tag:=-1;                               {No icon in panel2}
  StatusBar.Panels[1].Text:=IntToStr(list.Count);  {Number objects}
  StatusBar.Panels[2].Text:='';
  StatusBar.Hint:=hntStatusO;
  gridResults.RowCount:=1;                         {Delete result table first}
  gridResults.Rows[0].Delimiter:=sep;
  gridResults.Rows[0].DelimitedText:=rsObjHeader;
  gridResults.RowCount:=list.Count+1;              {Expand table to number objects}

  gridResults.BeginUpdate;
    for i:=0 to List.Count-1 do begin              {Show Object list instead}
      gridResults.Cells[0, i+1]:=list[i].Split([dpkt])[0];        {Object}
      gridResults.Cells[1, i+1]:=trim(list[i].Split([dpkt])[1]);  {Type}
      gridResults.Cells[2, i+1]:=IntToStr(i+1);                   {Number}
    end;
  gridResults.EndUpdate;

  gridResults.Tag:=1;                              {ID for Objects in list}
end;

procedure TMain.SetStatusbar(num: integer);        {Reset StatusBar Numbers}
begin
  StatusBar.Panels[0].Text:=IntToStr(num);
  StatusBar.Panels[1].Text:='';
  StatusBar.Panels[2].Text:='';
end;

procedure TMain.WaisenSuchen( fn: string);         {Search orphaned items}
var i, spp, zhl, idx: integer;
    inlist, objlist, proplist: TStringList;
    obj, ppr, rootobj: string;

begin
  inlist:=TStringList.Create;
  objlist:=TStringList.Create;
  objlist.CaseSensitive:=false;
  proplist:=TStringList.Create;
  proplist.Delimiter:=sep;
  proplist.StrictDelimiter:=true;
  gridResults.RowCount:=1;                         {Delete result table}
  gridResults.Rows[0].Delimiter:=sep;
  gridResults.Rows[0].DelimitedText:=rsHeader;
  Screen.Cursor:=crHourGlass;
  zhl:=0;                                          {Counter orphaned items}
  try
    inlist.LoadFromFile(fn);
    SetStatusbar(inlist.Count);                    {Reset StatusBar}
    if inlist.Count>4 then begin
      StatusBar.Panels[3].Text:=ExtractFileName(fn);
      mnSaveCSV.Enabled:=true;                     {Enable Save menu}

      spp:=findProperties(inlist, objlist);        {Scan all and create object list}

      if objlist.Count>0 then begin
        if spp<0 then begin                        {No SessionProperties available}
          StatusBar.Panels[3].Text:=rsNix;
          ShowObjectList(objlist);                 {Show object list instead}
        end else begin                             {SessionProperties available}
          rootobj:=trim(objlist[0].Split([dpkt])[0]); {Save class name TForm}
          proplist.DelimitedText:=inlist[spp];     {Session properties to stringlist}
          proplist.Sort;
          StatusBar.Panels[1].Text:=IntToStr(proplist.Count);
          if cbFilter.Checked then
            gridResults.RowCount:=1                {Start at first line}
          else                                     {Create whole result list and fill}
            gridResults.RowCount:=proplist.Count+1;

          CleanObj(objlist);
          gridResults.BeginUpdate;                 {Start scan in SessionProperties}
            for i:=0 to proplist.Count-1 do begin
              obj:=trim(proplist[i].Split([pkt])[0]); {Object from SessionProperties}
              ppr:=trim(proplist[i].Split([pkt])[1]); {Property}
              if ppr='' then begin                 {Assign to root object (TForm)}
                ppr:=obj;
                obj:=rootobj;
              end;
              idx:=objlist.IndexOf(obj);
              if idx<0 then
                inc(zhl);                          {Count orphaned items}
              ShowSearchResult(gridResults, i+1, obj, ppr,
                               cbFilter.Checked,   {Enabled only}
                               (idx<0));           {Orphaned}
            end;
          gridResults.EndUpdate;
          gridResults.Tag:=0;                      {ID for Properties in list}
          StatusBar.Panels[2].Text:=IntToStr(zhl);

          if zhl=0 then begin                      {no orphaned items found}
            StatusBar.Panels[3].Text:=ExtractFileName(fn)+' --> '+rsKeine;
            StatusBar.Tag:=2;                      {Green LED}
          end else
            StatusBar.Tag:=3;                      {Red LED}
        end;
      end else                                     {Object list empty}
        StatusBar.Panels[3].Text:=errNoObj;
    end else begin                                 {File empty}
      StatusBar.Panels[3].Text:=errEmpty;
    end;
  finally
    if gridResults.RowCount=1 then begin           {Empty results, nothing added}
      gridResults.RowCount:=defRows;               {Show nice empty table}
      mnSaveCSV.Enabled:=false;                    {Disable Save menu}
    end;
    inlist.Free;
    objList.Free;
    proplist.Free;
    screen.Cursor:=crDefault;
  end;
end;

procedure TMain.XML_read(fn: string; alist: TStringList);
var xlist: TXMLDocument;                           {Read XML file, create xmllist}
    objnode: TDOMNode;
    i, j: integer;
begin
  Screen.Cursor:=crHourGlass;
  ReadXMLfile(xlist, fn);
  try
    objnode:=xlist.DocumentElement.FirstChild;     {TApplication}
    while Assigned(objnode) do begin
      with objnode.ChildNodes do begin             {Form1, there is only one}
        try
          for i:=0 to (Count-1) do begin           {Attribute list: Session Properties}
            for j:=0 to Item[i].Attributes.Length-1 do begin
              alist.Add(Item[i].Attributes.Item[j].NodeName+gleich+
                        Item[i].Attributes.Item[j].NodeValue);
            end;
          end;
        finally
          Free;
        end;
      end;
      objnode:=objnode.NextSibling;                {Usually there is none}
    end;
  finally
    xlist.Free;
    Screen.Cursor:=crDefault;
  end;
end;

procedure TMain.XMLsuchen(fn: string);             {Open XML to check against lfm}
var i, zhl, idx: integer;
    inlist, objlist, xmllist, outlist: TStringList;
    rootid, obj, s: string;
begin
  inlist:=TStringList.Create;
  objlist:=TStringList.Create;
  objlist.CaseSensitive:=false;
  xmllist:=TStringList.Create;
  outlist:=TStringList.Create;
  gridResults.RowCount:=1;                         {Delete result table}
  gridResults.Rows[0].Delimiter:=sep;
  gridResults.Rows[0].DelimitedText:=rsXMLHeader;
  zhl:=0;
  try
    OpenDialog.Title:=ttOpenDialogLFM2;
    OpenDialog.FilterIndex:=1;                     {lfm file to check against}
    if OpenDialog.Execute then begin
      StatusBar.Panels[3].Text:=ExtractFileName(OpenDialog.FileName);
      inlist.LoadFromFile(OpenDialog.FileName);
      SetStatusbar(inlist.Count);                  {Reset StatusBar}
      if inlist.Count>4 then begin
        Screen.Cursor:=crHourGlass;
        findProperties(inlist, objlist);           {create object list}

        if objlist.Count>0 then begin
          StatusBar.Panels[1].Text:=IntToStr(objlist.Count);
          StatusBar.Panels[3].Text:=ExtractFileName(fn);

          XML_read(fn, xmllist);
          if xmllist.Count>1 then begin
            CleanObj(objlist);
            mnSaveCSV.Enabled:=true;               {Enable Save menu}
            if cbFilter.Checked then
              gridResults.RowCount:=1              {Start at first line}
            else                                   {Create whole result list and fill}
              gridResults.RowCount:=xmllist.Count;
            outlist.Add(xmllist[0]);               {Save '<TForm' start item}

            gridResults.BeginUpdate;               {Fill Result table}
              for i:=1 to xmllist.Count-1 do begin
                obj:=trim(xmllist[i].Split([xsep])[0]);
                idx:=objlist.IndexOf(obj);
                if idx<0 then
                  inc(zhl)                         {Count unused items}
                else
                  outlist.Add(xmllist[i]);         {Save valid items}
                ShowSearchResult(gridResults, i, obj,
                                 xmllist[i].Split([xsep, gleich])[1],
                                 cbFilter.Checked, (idx<0));
              end;
            gridResults.EndUpdate;
            StatusBar.Panels[2].Text:=IntToStr(zhl);
            gridResults.Tag:=2;                    {ID for Objects in XML}

            if zhl=0 then begin                    {No unused items found}
              StatusBar.Panels[3].Text:=ExtractFileName(fn)+' --> '+rsKeine;
              StatusBar.Tag:=3;                    {Green LED}
            end else begin                         {Unused found}
              StatusBar.Tag:=3;                    {Red LED}

              if cbDelete.Checked and              {if really needed}
                 (outlist.Count>1) then begin      {Save corrected XML file}
                inlist.LoadFromFile(fn);
                rootid:='<'+trim(objlist[0].Split([dpkt])[0]);
                s:=tabn+rootid;                    {Create new corrcted line}
                for i:=0 to outlist.Count-1 do begin
                  obj:=outlist[i].Split([gleich])[0];
                  s:=s+tab1+obj+gleich+
                     qchar+StringReplace(outlist[i], obj, '', [])+qchar;
                end;

                if length(s)>(length(tabn)+length(endm)) then begin
                  inlist.SaveToFile(ChangeFileExt(fn, backup));
                  for i:=0 to inlist.Count-1 do begin
                    if pos(rootid, inlist[i])>0 then begin
                      obj:=inlist[i];
                      if obj[length(obj)-1]=endm then
                        s:=s+endm;
                      s:=s+'>';
                      inlist[i]:=s;                {Replace SessionProperties}
                      break;
                    end;
                  end;
                  inlist.SaveToFile(fn);
                  StatusBar.Panels[3].Text:=ExtractFileName(fn)+tab1+
                                            rsCorrected;
                end;
              end;

            end;
          end else
            StatusBar.Panels[3].Text:=errNoXML;
        end else
          StatusBar.Panels[3].Text:=errNoObj;
      end else
        StatusBar.Panels[3].Text:=errEmpty;
    end;
  finally
    if gridResults.RowCount=1 then begin           {Empty results, nothing added}
      gridResults.RowCount:=defRows;               {Show nice empty table}
      mnSaveCSV.Enabled:=false;                    {Disable Save menu}
    end;
    inlist.Free;
    objlist.Free;
    xmllist.Free;
    outlist.Free;
    Screen.Cursor:=crDefault;
  end;
end;

procedure TMain.actCloseExecute(Sender: TObject);  {Action Close}
begin
  Close;
end;

procedure TMain.actSaveCSVExecute(Sender: TObject);
begin
  SaveDialog.Title:=ttSaveDialog;
  SaveDialog.InitialDir:=OpenDialog.InitialDir;
  case gridResults.Tag of                          {Propose file name}
    0: SaveDialog.Filename:=ChangeFileExt(OpenDialog.FileName, '')+xsep+
                                     kwSessProp+'.csv';
    1: SaveDialog.Filename:=ChangeFileExt(OpenDialog.FileName, '')+xsep+
                                       kwObject+'.csv';
    2: SaveDialog.Filename:=ChangeFileExt(OpenDialog.FileName, '')+xsep+
                                       rsXML+'.csv';
  end;

  if SaveDialog.Execute then begin                 {Save file}
    gridResults.SaveToCSVFile(SaveDialog.FileName, sep);
    StatusBar.Panels[3].Text:=rsSavedAs+ExtractFileName(SaveDialog.FileName);
  end;
end;

procedure TMain.actWaisenExecute(Sender: TObject);
begin
  StatusBar.Tag:=1;                                {Default icon shown}
  StatusBar.Refresh;
  StatusBar.Hint:=hntStatusW;
  OpenDialog.Title:=ttOpenDialogLFM1;
  OpenDialog.FilterIndex:=1;                       {.lfm file}
  if OpenDialog.Execute then
    WaisenSuchen(OpenDialog.FileName);
end;

procedure TMain.actXMLcheckExecute(Sender: TObject);
begin
  StatusBar.Tag:=5;                                {Default icon for XML shown}
  StatusBar.Refresh;
  StatusBar.Hint:=hntStatusW;
  OpenDialog.Title:=ttOpenDialogXML;
  OpenDialog.FilterIndex:=2;                       {.xml file}
  if OpenDialog.Execute then
    XMLSuchen(OpenDialog.FileName);                {File name of the XML file}
end;

end.

