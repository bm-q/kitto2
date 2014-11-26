{-------------------------------------------------------------------------------
   Copyright 2014 Ethea S.r.l.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
-------------------------------------------------------------------------------}

unit Kitto.Ext.DebenuQuickPDF.Tools;

interface

uses
  DB, DebenuPDFLibraryLite1112_TypeLibrary,
  SysUtils, Classes,
  EF.Tree,
  Kitto.Ext.Controller, Kitto.Ext.DataTool, Kitto.Ext.Base, Kitto.Ext.Tools,
  Kitto.Metadata.DataView, Kitto.Ext.StandardControllers;

type
  ELsPDFError = class(Exception) end;

  //Debenu Quick PDF Font definition
  TPDFStandardFont = (
    sfCourier,                 //0
    sfCourierBold,             //1
    sfCourierBoldOblique,      //2
    sfCourierOblique,          //3
    sfHelvetica,               //4
    sfHelveticaBold,           //5
    sfHelveticaBoldOblique,    //6
    sfHelveticaOblique,        //7
    sfTimesRoman,              //8
    sfTimesBold,               //9
    sfTimesItalic,             //10
    sfTimesBoldItalic,         //11
    sfSymbol,                  //12
    sfZapfDingbats);           //13

  TPDFTextAlign = (
    taLeft,                    //0
    taCenter,                  //1
    taRight,                   //2
    taJustified,               //3
    taForcejustified,          //4
    taLastlinejustified);      //5

  TPDFVertAlign = (
    vaCenter,                  //0
    vaTop,                     //1
    vaBottom,                  //2
    vaCenterNoWrap,            //3
    vaTopNoWrap,               //4
    vaBottomNoWrap);           //5

  TPDFMergeProgressEvent = procedure (const FileName: string; NewStartPage, PageCount: Integer) of Object;
  TPDFAcceptFileEvent = procedure (const FileName: string; var Accept: boolean) of Object;

type
  TMergePDFToolController = class(TKExtDownloadFileController)
  strict private
    FPDFDoc: TPDFLibrary;
    function GetPDFDoc: TPDFLibrary;
    procedure CheckDebenuPDFError(DebenuReturnCode: Integer;
      const FullFileName: string = '');
    function LoadLayout(const ALayoutFileName: string): TEFPersistentTree;
    property PDFDoc: TPDFLibrary read GetPDFDoc;
  strict
  private
    function GetLayoutFileName: string;
  private
    function GetBaseFileName: string; protected
    function GetDefaultFileName: string; override;
    procedure PrepareFile(const AFileName: string); override;
    function GetDefaultFileExtension: string; override;
  public
    class function GetDefaultImageName: string;
  published
    property LayoutFileName: string read GetLayoutFileName;
    property BaseFileName: string read GetBaseFileName;
  end;

implementation

uses
  System.Math , System.TypInfo, System.UIConsts, System.UITypes,
  Ext, EF.Classes, EF.StrUtils, EF.Localization, EF.DB, EF.SysUtils, EF.Macros,
  Kitto.Metadata.Models, Kitto.Ext.Session, Kitto.Config;

{ TMergePDFToolController }

procedure TMergePDFToolController.CheckDebenuPDFError(DebenuReturnCode: Integer;
  const FullFileName: string = '');
var
  ErrorMsg: string;
  DebenuErrorCode: Integer;
begin
  if DebenuReturnCode <> 0 then
    Exit
  else
    DebenuErrorCode := PDFDoc.LastErrorCode;

  case DebenuErrorCode of
    101: ErrorMsg := _('The Strength parameter passed to the Encrypt function was invalid');
    102: ErrorMsg := _('The Permissions parameter passed to the Encrypt function was invalid.');
    103: ErrorMsg := _('The Encrypt function was used on a document that was already encrypted');
    104: ErrorMsg := _('The Encrypt function failed for an unknown reason');
    201: ErrorMsg := _('The SetInformation function failed because the document is encrypted');
    202: ErrorMsg := _('The Key parameter passed to the SetInformation function was out of range');
    301: ErrorMsg := _('An invalid combination of barcode and option was sent to the DrawBarcode function');
    302: ErrorMsg := _('Non-numeric characters were sent to DrawBarcode using EAN-13');
    303: ErrorMsg := _('The EAN-13 barcode has an invalid checksum character');
    401: ErrorMsg := _('Could not open input file');
    402: ErrorMsg := _('Output file already exists and could not be deleted');
    403: ErrorMsg := _('Could not open output file');
    404: ErrorMsg := _('Invalid password');
    405: ErrorMsg := _('Document is not encrypted');
    406: ErrorMsg := _('Document is already encrypted');
    407: ErrorMsg := _('Invalid encryption strength');
    408: ErrorMsg := _('Invalid permissions');
    409: ErrorMsg := _('Invalid file structure, file is damaged');
    410: ErrorMsg := _('One of the input files is encrypted');
    411: ErrorMsg := _('File not found');
    412: ErrorMsg := _('Invalid page range list');
    501: ErrorMsg := _('The specified FileHandle was invalid');
    999: ErrorMsg := _('The function could not be used because the library is not unlocked');
  else
    ErrorMsg := _( 'Error unknown of Debenu Quick PDF Library (DebenuPDFLibraryLite1112.dll)');
  end;
  if FullFileName <> '' then
    ErrorMsg := Format(_('Error on file "%s": %s' ), [FullFileName, ErrorMsg]);
  raise ELsPDFError.Create(ErrorMsg);
end;

function TMergePDFToolController.GetBaseFileName: string;
begin
  Result := Config.GetExpandedString('BaseFileName');
end;

function TMergePDFToolController.GetDefaultFileExtension: string;
begin
  Result := '.pdf';
end;

function TMergePDFToolController.GetDefaultFileName: string;
var
  LFileExtension: string;
begin
  LFileExtension := ExtractFileExt(ClientFileName);
  if LFileExtension = '' then
    LFileExtension := GetDefaultFileExtension;
  Result := EF.SysUtils.GetTempFileName(LFileExtension);
  AddTempFilename(Result);
end;

class function TMergePDFToolController.GetDefaultImageName: string;
begin
  Result := 'pdf_document';
end;

function TMergePDFToolController.GetLayoutFileName: string;
begin
  Result := Config.GetExpandedString('Layout');
end;

function TMergePDFToolController.GetPDFDoc: TPDFLibrary;
begin
  if not Assigned(FPDFDoc) then
  begin
    FPDFDoc := TPDFLibrary.Create(nil);
    try
      FPDFDoc.Connect;
    except
      On E: Exception do
        raise ELsPDFError.CreateFmt(_('Error using DebenuPDFLibraryLite1012.dll library: %s' ),[E.Message]);
    end;
  end;
  Result := FPDFDoc;
end;

function TMergePDFToolController.LoadLayout(const ALayoutFileName: string): TEFPersistentTree;
begin
  Assert(FileExists(ALayoutFileName), 'Layout file at node Layout not found');
  Result := TEFTreeFactory.LoadFromFile<TEFComponentConfig>(ALayoutFileName);
end;

procedure TMergePDFToolController.PrepareFile(const AFileName: string);
var
  LRecord: TKViewTableRecord;
  LBaseFileName: string;
  LExpression, LImageFileName, LText: string;
  LNode, LItems: TEFNode;
  I, LLeft, LTop, LWidth, LHeight, LXPos, LYPos, LFontNumber: Integer;
  LFontSize, LDefaultFontSize: Double;
  LFontColor: TAlphaColor;
  LDefaultFontColor: TAlphaColor;
  LDefaultFontNumber: Integer;
  LField: TKViewTableField;
  LVertAlign, LAlign: Integer;
  LLayoutFileName: TEFPersistentTree;

  procedure AddImage(const AImageFileName: string; ALeft, ATop, AWidth, AHeight: Integer);
  begin
    CheckDebenuPDFError(FPDFDoc.AddImageFromFile(AImageFileName, 0),AImageFileName);
    CheckDebenuPDFError(FPDFDoc.DrawImage(ALeft, ATop, AWidth, AHeight));
  end;

  procedure SetupFont(const AFontSize: Double; const AFontColor: TAlphaColor;
    const AFontNumber: integer);
  var
    LFontId: Integer;
    LColorR, LColorG, LColorB: Byte;
 begin
    if AFontNumber <> -1 then
    begin
      LFontId := FPDFDoc.AddStandardFont(LFontNumber);
      FPDFDoc.SelectFont(LFontId);
    end;
    if AFontSize > 0 then
      CheckDebenuPDFError(FPDFDoc.SetTextSize(AFontSize));
    LColorR := TAlphaColorRec(AFontColor).R;
    LColorG := TAlphaColorRec(AFontColor).G;
    LColorB := TAlphaColorRec(AFontColor).B;
    CheckDebenuPDFError(FPDFDoc.SetTextColor(LColorR, LColorG, LColorB));
  end;

  procedure AddText(const AText: string;
    const AFontSize: Double; const AFontColor: TAlphaColor;
    const AFontNumber, AXPos, AYPos: Integer);
  begin
    SetupFont(AFontSize, AFontColor, AFontNumber);
    //Draw Text into PDF
    CheckDebenuPDFError(FPDFDoc.DrawText(AXPos, AYPos, AText));
  end;

  procedure AddTextBox(const AText: string;
    const AFontSize: Double; const AFontColor: TAlphaColor;
    const AFontNumber, ALeft, ATop, AWidth, AHeight: Integer;
    const AAlign, AVertAlign: Integer);
  var
    LAlign: Integer;
    LVertAlign: Integer;
  begin
    SetupFont(AFontSize, AFontColor, AFontNumber);
    LAlign := IfThen(AAlign <> -1, AAlign, 0);
    LVertAlign := IfThen(AVertAlign <> -1, AVertAlign, 0);
    CheckDebenuPDFError(FPDFDoc.SetTextAlign(LAlign));
    CheckDebenuPDFError(FPDFDoc.DrawTextBox(ALeft, ATop, AWidth, AHeight, AText, LVertAlign));
  end;

  procedure GetFontAttributes(AParentNode: TEFTree; const NodeName: string;
    out AFontNumber: Integer; out AFontSize: double; out AColor: TAlphaColor);
  var
    LFontName, LColorName: string;
    LFontNode: TEFNode;
  begin
    LFontNode := AParentNode.FindNode(NodeName);
    if Assigned(LFontNode) then
    begin
      LFontName := LFontNode.AsString;
      AFontNumber := GetEnumValue(TypeInfo(TPDFStandardFont),'sf'+LFontName);
      AFontSize := LFontNode.GetFloat('Size',-1);
      LColorName := LFontNode.GetString('Color');
      if LColorName <> '' then
        AColor := StringToAlphaColor(LColorName)
      else
        AColor := LDefaultFontColor;
    end
    else
    begin
      AFontNumber := LDefaultFontNumber;
      AFontSize := LDefaultFontSize;
      AColor := LDefaultFontColor;
    end;
  end;

  function ExpandExpression(const Expression: string): string;
  var
    LFieldName: string;
  begin
    LFieldName :=  StripPrefixAndSuffix(LExpression,'%','%');
    LField := LRecord.FindField(LFieldName);
    if Assigned(LField) then
      Result := LField.AsString
    else
      Result := LFieldName;
  end;

begin
  LRecord := ServerRecord;
  LLayoutFileName := LoadLayout(LayoutFileName);
  LBaseFileName := BaseFileName;
  CheckDebenuPDFError(PDFDoc.LoadFromFile(LBaseFileName,''),LBaseFileName);

  //Initialize default font informations
  LDefaultFontNumber := 0;
  LDefaultFontSize := 10;
  LDefaultFontColor := claBlack;
  GetFontAttributes(LLayoutFileName.Root, 'DefaultFont', LDefaultFontNumber, LDefaultFontSize, LDefaultFontColor);

  //Images node
  LItems := LLayoutFileName.FindNode('Items');
  if Assigned(LItems) then
  begin
    for I := 0 to LItems.ChildCount - 1 do
    begin
      LNode := LItems.Children[I];
      if SameText(LNode.Name,'Image') then
      begin
        //image properties
        LImageFileName := LNode.GetString('FileName');
        LLeft := LNode.GetInteger('Left');
        LTop := LNode.GetInteger('Top');
        LWidth := LNode.GetInteger('Width');
        LHeight := LNode.GetInteger('Height');
        //Add an image
        LImageFileName := TKConfig.FindResourcePathName(LImageFileName);
        AddImage(LImageFileName,LLeft,LTop,LWidth,LHeight);
      end
      else if SameText(LNode.Name,'Text') then
      begin
        LExpression := LNode.GetString('Expression');
        LText := ExpandExpression(LExpression);
        LXPos := LNode.GetInteger('XPos');
        LYPos := LNode.GetInteger('YPos');
        GetFontAttributes(LNode, 'Font', LFontNumber, LFontSize, LFontColor);
        //Add a Text
        AddText(LText, LFontSize, LFontColor, LFontNumber, LXPos, LYPos);
      end
      else if SameText(LNode.Name,'TextBox') then
      begin
        //TextBox properties
        LExpression := LNode.GetString('Expression');
        LText := ExpandExpression(LExpression);
        LLeft := LNode.GetInteger('Left');
        LTop := LNode.GetInteger('Top');
        LWidth := LNode.GetInteger('Width');
        LHeight := LNode.GetInteger('Height');

        GetFontAttributes(LNode, 'Font', LFontNumber, LFontSize, LFontColor);
        LVertAlign := GetEnumValue(TypeInfo(TPDFVertAlign),'va'+LNode.GetString('VertAlign'));
        LAlign := GetEnumValue(TypeInfo(TPDFTextAlign),'ta'+LNode.GetString('Align'));
        //Add a TextBox
        AddTextBox(LText, LFontSize, LFontColor, LFontNumber, LLeft, LTop, LWidth, LHeight, LAlign, LVertAlign);
      end;
    end;
  end;

  //Salva il file
  CheckDebenuPDFError(FPDFDoc.SaveToFile(AFileName),AFileName);
end;

initialization
  TKExtControllerRegistry.Instance.RegisterClass('MergePDFTool', TMergePDFToolController);

finalization
  TKExtControllerRegistry.Instance.UnregisterClass('MergePDFTool');

end.
