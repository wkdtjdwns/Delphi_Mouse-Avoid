unit Main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls;

type
  { 오브젝트 목록 }
  TObjectType = (ObjA, ObjB, ObjC, ObjD, ObjMouse, ObjFollow);
  {
    ObjA: Small & Fast
    ObjB: Normal Obj
    ObjC: Random Direction Move
    ObjD: Rotating Object
    ObjFollow: Mouse Following Enemy Object
    ObjMouse: Mouse Following Object
  }

  { 기본 오브젝트 }
  TBaseObject = class
  public
    ObjType: TObjectType;
    X, Y: Integer;
    Width, Height: Integer;
    SpeedX, SpeedY: Integer;
    IsDead: Boolean;

    constructor Create; virtual;
    procedure Move; virtual;
    property Dead: Boolean read IsDead write IsDead;
  end;

  { A 오브젝트 }
  TObjA = class(TBaseObject)
    constructor Create; override;
    procedure Move; override;
  end;

  { B 오브젝트 }
  TObjB = class(TBaseObject)
    constructor Create; override;
    procedure Move; override;
  end;

  { C 오브젝트 }
  TObjC = class(TBaseObject)
  private
    MoveTime: Integer;  // 이동 시간
    StopTime: Integer;  // 정지 시간

    IsStopped: Boolean;

    SpeedOptionsX: array[0..6] of Integer;
    SpeedOptionsY: array[0..6] of Integer;

    MaxMoveTime: Integer;
    MaxStopTime: Integer;
  public
    constructor Create; override;
    procedure Move; override;
  end;

  { D 오브젝트 }
  TObjD = class(TBaseObject)
  private
    CenterX, CenterY: Integer;  // 회전 중심
    Radius: Integer;            // 회전 반경
    Angle: Double;              // 현재 회전 각도
    AngularSpeed: Double;       // 각 속도
  public
    constructor Create; override;
    procedure Move; override;
  end;

  { Follow 오브젝트 }
  TObjFollow = class(TBaseObject)
  private
    CurSpeed: Double;
    MaxSpeed: Double;
    SpeedUpInterval: Integer;
    SpeedUpTimer: Integer;
  public
    constructor Create; override;
    procedure Move; override;
  end;

  { Mouse 오브젝트 }
  TObjMouse = class(TBaseObject)
  public
    constructor Create; override;
    procedure Move; override;
    procedure SetPosition(AX, AY: Integer);
  end;

  TForm1 = class(TForm)
    Panel1: TPanel;
    Timer1: TTimer;
    TimerSpawn: TTimer;
    PaintBox1: TPaintBox;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure TimerSpawnTimer(Sender: TObject);
    procedure PaintBox1MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
  private
    Objects: TList;
    MouseFollower: TObjMouse;
    GameOver: Boolean;

    Score: Integer;
    ScoreTimer: Integer;
    MaxScore: Integer;

    BlackHoleCenter: TPoint;
    IsBlackHoleActive: Boolean;
    BlackHoleTimer: Integer;
    BlackHoleDuration: Integer;
    IsBurstActive: Boolean;
    BurstDuration: Integer;

    BlackHoleSpawnTimer: Integer;
    BlackHoleSpawnInterval: Integer;

    function CheckCollision(obj1, obj2: TBaseObject): Boolean;
    procedure CreateRandomObject;
    procedure CreateFollowObject;
    procedure ResetGame;
    procedure UpdateScore;
    procedure RemoveFollowObjects;

    // 블랙홀 효과 관련 함수
    procedure ActivateBlackHole(const APoint: TPoint; ATriggeredObj: TObjFollow = nil);
    procedure UpdateBlackHoleEffect;
    procedure DrawBlackHoleEffect;
  public
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

{ TBaseObject }
constructor TBaseObject.Create;
begin
  inherited Create;

  { 기본 설정 }
  Width := 10;
  Height := 10;

  SpeedX := 0;
  SpeedY := 0;

  IsDead := False;

  { Form1 및 Panel1이 유효할 경우, 무작위 위치에 생성 }
  if Assigned(Form1) and Assigned(Form1.Panel1) then
  begin
    X := Random(Form1.Panel1.Width - Width);
    Y := Random(Form1.Panel1.Height - Height);
  end
  else
  begin
    { 기본 값 }
    X := Random(400);
    Y := Random(300);
  end;
end;

procedure TBaseObject.Move;
var
  DeltaX, DeltaY, Distance: Double;
  EffectSpeed: Double;
begin
  { Form1 및 Panel1이 유효할 경우 }
  if not (Assigned(Form1) and Assigned(Form1.Panel1)) then Exit;

  { ObjMouse는 모든 효과 무시 }
  if ObjType = ObjMouse then
  begin
    Exit;
  end;

  { 블랙홀 생성 시 }
  if Form1.IsBlackHoleActive then
  begin
    { 블랙홀의 중심으로 끌어당겨짐 }
    DeltaX := Form1.BlackHoleCenter.X - (X + Width div 2);
    DeltaY := Form1.BlackHoleCenter.Y - (Y + Height div 2);
    Distance := Sqrt(DeltaX * DeltaX + DeltaY * DeltaY);

    { 블랙홀이 끌어당기는 속도 조절 }
    EffectSpeed := 20;

    { 블랙홀과의 거리가 너무 가까우면 중앙에 배치함 }
    if Distance < EffectSpeed then
    begin
      X := Form1.BlackHoleCenter.X - Width div 2;
      Y := Form1.BlackHoleCenter.Y - Height div 2;
      SpeedX := 0;
      SpeedY := 0;
    end

    { 가깝지 않으면 계속 이동 }
    else if Distance > 0 then
    begin
      SpeedX := Round(DeltaX / Distance * EffectSpeed);
      SpeedY := Round(DeltaY / Distance * EffectSpeed);
    end

    { 정확히 중앙에 오면 멈춤 }
    else
    begin
      SpeedX := 0;
      SpeedY := 0;
    end;

    Inc(X, SpeedX);
    Inc(Y, SpeedY);
  end

  { 버스트 중일 시 }
  else if Form1.IsBurstActive then
  begin
    { 블랙홀의 중심점에서 멀리 멀려남 (현재 위치를 기준으로 방향 설정) }
    DeltaX := (X + Width div 2) - Form1.BlackHoleCenter.X;
    DeltaY := (Y + Height div 2) - Form1.BlackHoleCenter.Y;
    Distance := Sqrt(DeltaX * DeltaX + DeltaY * DeltaY);

    { 밀려나는 속도 조정 }
    EffectSpeed := 30;

    { 블랙홀과의 거리에 따른 속도 조정 }

    { 너무 가까우면 랜덤한 방향으로 밀려남 }
    if Distance < 10 then
    begin
        DeltaX := Random(200) - 100;
        DeltaY := Random(200) - 100;

        Distance := Sqrt(DeltaX * DeltaX + DeltaY * DeltaY);
    end;

    if Distance > 0 then
    begin
      SpeedX := Round(DeltaX / Distance * EffectSpeed);
      SpeedY := Round(DeltaY / Distance * EffectSpeed);
    end

    { 정확히 중심이면 랜덤하게 밀려남 }
    else
    begin
      SpeedX := Random(20) - 10;
      SpeedY := Random(20) - 10;
    end;

    Inc(X, SpeedX);
    Inc(Y, SpeedY);

    { 버스트 중에는 벽에 닿아도 제거 X -> 충돌 로직 X }
  end

  { 일반 이동 시 }
  else
  begin
    { 현재 속도 만큼 이동 }
    Inc(X, SpeedX);
    Inc(Y, SpeedY);

    { 벽에 닿았을 경우 회전 }
    if X < 0 then
    begin
      X := 0;
      SpeedX := -SpeedX;
    end;

    if Y < 0 then
    begin
      Y := 0;
      SpeedY := -SpeedY;
    end;

    if X > Form1.Panel1.Width - Width then
    begin
      X := Form1.Panel1.Width - Width;
      SpeedX := -SpeedX;
    end;

    if Y > Form1.Panel1.Height - Height then
    begin
      Y := Form1.Panel1.Height - Height;
      SpeedY := -SpeedY;
    end;
  end;
end;

{ TObjA }
constructor TObjA.Create;
begin
  inherited Create; // Base의 Create 사용
  ObjType := ObjA;

  Width := 50;
  Height := 50;

  SpeedX := 10;
  SpeedY := 10;
end;

procedure TObjA.Move;
begin
  inherited Move;   // Base의 Move 사용
end;

{ TObjB }
constructor TObjB.Create;
begin
  inherited Create; // Base의 Create 사용
  ObjType := ObjB;

  Width := 75;
  Height := 75;

  SpeedX := 5;
  SpeedY := 5;
end;

procedure TObjB.Move;
begin
  inherited Move;   // Base의 Move 사용
end;

{ TObjC }
constructor TObjC.Create;
begin
  inherited Create; // Base의 Create 사용
  ObjType := ObjC;

  Width := 35;
  Height := 35;

  { 속도 범위 지정 }
  SpeedOptionsX[0] := -30;
  SpeedOptionsX[1] := -15;
  SpeedOptionsX[2] := -5;
  SpeedOptionsX[3] := 0;
  SpeedOptionsX[4] := 5;
  SpeedOptionsX[5] := 15;
  SpeedOptionsX[6] := 30;

  SpeedOptionsY[0] := -30;
  SpeedOptionsY[1] := -15;
  SpeedOptionsY[2] := -5;
  SpeedOptionsY[3] := 0;
  SpeedOptionsY[4] := 5;
  SpeedOptionsY[5] := 15;
  SpeedOptionsY[6] := 30;

  { 지정한 속도 범위에서 랜덤한 값 지정 }
  SpeedX := SpeedOptionsX[Random(Length(SpeedOptionsX))];
  SpeedY := SpeedOptionsY[Random(Length(SpeedOptionsY))];

  MoveTime := 0;
  StopTime := 0;

  IsStopped := False;

  MaxMoveTime := 0;
  MaxStopTime := 0;
end;

procedure TObjC.Move;
begin
  { 블랙홀 발동 시 Base의 Move 사용 }
  if Form1.IsBlackHoleActive or Form1.IsBurstActive then
  begin
    inherited Move;
  end

  { 블랙홀이 발동되지 않았을 때만 C만의 Move 사용 }
  else
  begin
    { 멈춰있을 때 }
    if IsStopped then
    begin
      { 멈출 시간 지정 }
      if MaxStopTime = 0 then
        MaxStopTime := 5 + Random(16);

      Inc(StopTime);

      { 멈춰야 할 시간동안 멈춘 뒤 }
      if StopTime >= MaxStopTime then
      begin
        { 속도를 다시 지정하고 멈추기 중지 }
        SpeedX := SpeedOptionsX[Random(Length(SpeedOptionsX))];
        SpeedY := SpeedOptionsY[Random(Length(SpeedOptionsY))];

        StopTime := 0;
        MaxStopTime := 0;

        IsStopped := False;
      end;
    end
    { 움직일 때 }
    else
    begin
      inherited Move;

      { 이동할 시간 지정 }
      if MaxMoveTime = 0 then
        MaxMoveTime := 10 + Random(51);

      { 이동 시간 증가 }
      Inc(MoveTime);

      { 이동할 시간만큼 움직이면 정지 }
      if MoveTime >= MaxMoveTime then
      begin
        SpeedX := 0;
        SpeedY := 0;

        MoveTime := 0;
        MaxMoveTime := 0;

        IsStopped := True;
      end;
    end;
  end;
end;

{ TObjD }
constructor TObjD.Create;
begin
  inherited Create;
  ObjType := ObjD;

  Width := 30;
  Height := 30;

  if Assigned(Form1) and Assigned(Form1.Panel1) then
  begin
    { 중앙 위치 조정 }
    CenterX := Random(Form1.Panel1.Width - Width) + Width div 2;
    CenterY := Random(Form1.Panel1.Height - Height) + Height div 2;
  end
  else
  begin
    { 기본 값 }
    CenterX := Random(400) + 15;
    CenterY := Random(300) + 15;
  end;

  { Radius 초기 값 설정 (5 ~ 50) }
  Radius := 5 + Random(46);

  { 초기 각도 설정 }
  Angle := 0;

  { AngularSpeed 초기 값 설정 (Pi/60 ~ Pi/15) }
  AngularSpeed := (Pi / 60) + (Random * (Pi / 15 - Pi / 60));

  SpeedX := 0;
  SpeedY := 0;

  IsDead := False;
end;

procedure TObjD.Move;
var
  NewX, NewY: Integer;
begin
  if IsDead then Exit;

  { 블랙홀 및 버스트 중이면 Base의 Move 사용 }
  if Form1.IsBlackHoleActive or Form1.IsBurstActive then
  begin
    inherited Move;
  end

  { 일반 이동 시 }
  else
  begin
    if not (Assigned(Form1) and Assigned(Form1.Panel1)) then Exit;

    { 각을 계속 벌리면서 빙글빙글 돌게 함 }
    Radius := Radius + 1;
    if Radius > (Form1.Panel1.Width div 2) then
      Radius := 10;

    Angle := Angle + AngularSpeed;
    if Angle > 2 * Pi then
      Angle := Angle - 2 * Pi;

    NewX := CenterX + Round(Radius * Cos(Angle));
    NewY := CenterY + Round(Radius * Sin(Angle));

    { 벽에 닿으면 제거 }
    if (NewX < 0) or (NewY < 0) or
        (NewX > Form1.Panel1.Width - Width) or
        (NewY > Form1.Panel1.Height - Height) then
    begin
      IsDead := True;
      Exit;
    end;

    X := NewX;
    Y := NewY;

    { 다른 오브젝트들 간의 충돌 무시 -> 충돌 로직 X }
  end;
end;

{ TObjFollow }
constructor TObjFollow.Create;
begin
  inherited Create;
  ObjType := ObjFollow;

  Width := 40;
  Height := 40;

  { 초기 속도 }
  CurSpeed := 5.0;

  { 속도 증가 간격 (0.5초마다) }
  SpeedUpInterval := Round(500 / Form1.Timer1.Interval);

  { Interval이 0이 되는 것을 방지함 }
  if SpeedUpInterval = 0 then SpeedUpInterval := 1;

  { 속도 증가 타이머 설정 }
  SpeedUpTimer := 0;

  { 최대 속도 제한 }
  MaxSpeed := 30.0;
end;

procedure TObjFollow.Move;
var
  TargetX, TargetY: Integer;
  DeltaX, DeltaY: Double;
  Distance: Double;
begin
  if IsDead then Exit;
  if not (Assigned(Form1) and Assigned(Form1.Panel1) and Assigned(Form1.MouseFollower)) then Exit;

  if not (Form1.IsBlackHoleActive or Form1.IsBurstActive) then
  begin
    { 마우스 위치 가져오기 }
    TargetX := Form1.MouseFollower.X + Form1.MouseFollower.Width div 2;
    TargetY := Form1.MouseFollower.Y + Form1.MouseFollower.Height div 2;

    { Follow의 중심점 }
    DeltaX := TargetX - (X + Width div 2);
    DeltaY := TargetY - (Y + Height div 2);

    { 마우스와의 거리 계산 }
    Distance := Sqrt(DeltaX * DeltaX + DeltaY * DeltaY);

    { 마우스와의 거리가 0이 아닐 때 }
    if Distance > 0 then
    begin
      { 속도 지정 (방향도 같이 지정) }
      SpeedX := Round(DeltaX / Distance * CurSpeed);
      SpeedY := Round(DeltaY / Distance * CurSpeed);
    end
    else
    begin
      SpeedX := 0;
      SpeedY := 0;
    end;

    { 이동 }
    Inc(X, SpeedX);
    Inc(Y, SpeedY);

    { 속도를 점진적으로 증가 }
    Inc(SpeedUpTimer);
    if SpeedUpTimer >= SpeedUpInterval then
    begin
      { 0.5씩 증가 }
      CurSpeed := CurSpeed + 0.5;

      { 최대 속도 제한 }
      if CurSpeed > MaxSpeed then
        CurSpeed := MaxSpeed;

      SpeedUpTimer := 0;
    end;
  end

  { 블랙홀 및 버스트 중에는 Base에서 Move를 호출해 끌려가게 함 }
  else
  begin
    inherited Move;
  end;
end;


{ TObjMouse }
constructor TObjMouse.Create;
begin
  inherited Create;

  ObjType := ObjMouse;
  Width := 25;
  Height := 25;

  { 초기 위치 설정 }
  if Assigned(Form1) and Assigned(Form1.Panel1) then
  begin
    X := Form1.Panel1.Width div 2 - Width div 2;
    Y := Form1.Panel1.Height div 2 - Height div 2;
  end
  else
  begin
    { 기본 값 }
    X := 200;
    Y := 150;
  end;
end;

procedure TObjMouse.Move;
begin
  // 마우스 오브젝트는 Move에서 아무것도 하지 않음
  // 위치는 SetPosition으로만 설정됨
end;

{ 마우스 오브젝트 위치 설정 }
procedure TObjMouse.SetPosition(AX, AY: Integer);
begin
  { 마우스 위치로 이동 }
  X := AX - Width div 2;
  Y := AY - Height div 2;
end;

{ TForm1 }

{ 점수 업데이트 }
procedure TForm1.UpdateScore;
begin
  Inc(ScoreTimer);
  { 약 1초마다 점수 증가 }
  if ScoreTimer >= Round(1000 / Timer1.Interval) then
  begin
    Inc(Score);
    ScoreTimer := 0;
  end;
end;

{ 오브젝트 충돌 체크 }
function TForm1.CheckCollision(obj1, obj2: TBaseObject): Boolean;
begin
  Result := (obj1.X < obj2.X + obj2.Width) and
            (obj1.X + obj1.Width > obj2.X) and
            (obj1.Y < obj2.Y + obj2.Height) and
            (obj1.Y + obj1.Height > obj2.Y);
end;

{ 게임 초기화 }
procedure TForm1.ResetGame;
var
  i: Integer;
begin
  { 마우스 오브젝트를 제외한 모든 오브젝트 제거 }
  if Assigned(Objects) then
  begin
    for i := Objects.Count - 1 downto 0 do
    begin
      if TBaseObject(Objects[i]).ObjType <> ObjMouse then
      begin
        TObject(Objects[i]).Free;
        Objects.Delete(i);
      end;
    end;
  end;

  { 마우스 오브젝트 위치 초기화 }
  if Assigned(MouseFollower) then
  begin
    MouseFollower.X := Panel1.Width div 2 - MouseFollower.Width div 2;
    MouseFollower.Y := Panel1.Height div 2 - MouseFollower.Height div 2;
  end;

  { 초기 오브젝트 생성 }
  CreateRandomObject;

  { 게임 초기화 }
  GameOver := False;

  if Score > MaxScore then
    MaxScore := Score;

  Score := 1;
  ScoreTimer := 0;

  { 블랙홀 초기화 }
  IsBlackHoleActive := False;
  IsBurstActive := False;
  BlackHoleTimer := 0;
  BlackHoleSpawnTimer := 0;

  { 타이머 초기화 }
  Timer1.Enabled := True;
  TimerSpawn.Enabled := True;
end;

{ 오브젝트 소환 }
procedure TForm1.CreateRandomObject;
var
  obj: TBaseObject;
  ObjTypeIndex: Integer;
  i: Integer;
begin
  { 오브젝트 3개 소환 }
  for i := 0 to 2 do
  begin
    // ObjMouse와 ObjFollow를 제외한 타입들 중 선택 (ObjA, ObjB, ObjC, ObjD)
    ObjTypeIndex := Random(Ord(ObjMouse));

    { 오브젝트 소환 }
    case TObjectType(ObjTypeIndex) of
      ObjA: obj := TObjA.Create;
      ObjB: obj := TObjB.Create;
      ObjC: obj := TObjC.Create;
      ObjD: obj := TObjD.Create;
    else
      obj := TObjA.Create;
    end;

    Objects.Add(obj);
  end;
end;

{ ObjFollow 오브젝트 생성 }
procedure TForm1.CreateFollowObject;
var
  obj: TBaseObject;
begin
  obj := TObjFollow.Create;
  Objects.Add(obj);
end;

{ ObjFollow 제거 }
procedure TForm1.RemoveFollowObjects;
var
  i: Integer;
  obj: TBaseObject;
begin
  { 인덱스가 꼬이지 않게 역순 조회 }
  for i := Objects.Count - 1 downto 0 do
  begin
    obj := TBaseObject(Objects[i]);

    { ObjFollow면 }
    if obj.ObjType = ObjFollow then
    begin
      { 제거 }
      Objects.Delete(i);
      obj.Free;
    end;
  end;
end;

{ 블랙홀 활성화 함수 }
procedure TForm1.ActivateBlackHole(const APoint: TPoint; ATriggeredObj: TObjFollow = nil);
begin
  if not IsBlackHoleActive then
  begin
    { 블랙홀 생성 }
    IsBlackHoleActive := True;

    BlackHoleTimer := 0;
    BlackHoleCenter := APoint;
  end;
end;

{ 블랙홀 및 폭발 효과 업데이트 함수 }
procedure TForm1.UpdateBlackHoleEffect;
begin
  { 블랙홀 생성 시 }
  if IsBlackHoleActive then
  begin
    Inc(BlackHoleTimer);

    { 블랙홀 진행 종료 }
    if BlackHoleTimer >= BlackHoleDuration then
    begin
      { 버스트 시작 }
      IsBlackHoleActive := False;
      IsBurstActive := True;
      BlackHoleTimer := 0;
    end;
  end;

  { 버스트 시작 시 }
  if IsBurstActive then
  begin
    Inc(BlackHoleTimer);

    { 버스트 진행 종료 }
    if BlackHoleTimer >= BurstDuration then
    begin
      IsBurstActive := False;
      BlackHoleTimer := 0;

      RemoveFollowObjects;
    end;
  end;
end;

{ 블랙홀 이펙트 그리기 }
procedure TForm1.DrawBlackHoleEffect;
var
  EffectRadius: Integer;
begin
  if IsBlackHoleActive then
  begin
    { 시간에 따라 이펙트 크기 변경 }
    EffectRadius := Round(5 + (BlackHoleTimer / BlackHoleDuration) * 75); // 5 ~ 75

    { 블랙홀 그리기 }
    PaintBox1.Canvas.Pen.Color := clPurple;
    PaintBox1.Canvas.Brush.Color := clBlack;

    PaintBox1.Canvas.Ellipse(
      BlackHoleCenter.X - EffectRadius,
      BlackHoleCenter.Y - EffectRadius,
      BlackHoleCenter.X + EffectRadius,
      BlackHoleCenter.Y + EffectRadius
    );
  end;
end;

{ 프로젝트 시작 }
procedure TForm1.FormCreate(Sender: TObject);
begin
  { 게임에 쓰이는 변수 초기화 }
  Objects := TList.Create;

  GameOver := False;

  Score := 1;
  ScoreTimer := 0;

  Randomize;

  { 게임 타이머 }
  Timer1.Interval := 30; // 30ms = 약 33 FPS
  Timer1.Enabled := True;

  { Spawn 타이머 }
  TimerSpawn.Interval := 10000; // 10초
  TimerSpawn.Enabled := True;

  { 블랙홀 및 폭발 관련 변수 초기화 }
  IsBlackHoleActive := False;
  IsBurstActive := False;
  BlackHoleTimer := 0;

  { 블랙홀 및 버스트 효과 }
  BlackHoleDuration := Round(2000 / Timer1.Interval); // 2초
  BurstDuration := Round(1000 / Timer1.Interval);     // 1초

  { 블랙홀 생성 시간 (25초마다) }
  BlackHoleSpawnInterval := Round(25000 / Timer1.Interval);
  BlackHoleSpawnTimer := 0;

  { 윈도우 설정 }
  WindowState := wsMaximized; // 전체화면
  Cursor := crNone;           // 마우스 커서 숨김
  PaintBox1.Cursor := crNone; // PaintBox에서도 커서 숨김
  DoubleBuffered := True;     // 깜빡임 방지

  { 마우스 오브젝트 생성 }
  MouseFollower := TObjMouse.Create;
  Objects.Add(MouseFollower);

  { 오브젝트 생성 }
  CreateRandomObject;
end;

{ 프로젝트 종료 시 }
procedure TForm1.FormDestroy(Sender: TObject);
var
  i: Integer;
begin
  { List 해제 }
  if Assigned(Objects) then
  begin
    for i := 0 to Objects.Count - 1 do
      TObject(Objects[i]).Free;
    Objects.Free;
  end;
end;

{ 마우스를 움직일 때마다 }
procedure TForm1.PaintBox1MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  { 마우스 오브젝트 위치 초기화 }
  if Assigned(MouseFollower) then
    MouseFollower.SetPosition(X, Y);
end;

{ Spawn 타이머 }
procedure TForm1.TimerSpawnTimer(Sender: TObject);
begin
  if not GameOver then
  begin
    CreateRandomObject;
    CreateFollowObject;
  end;
end;

{ 타이머 이벤트 }
procedure TForm1.Timer1Timer(Sender: TObject);
var
  i, j: Integer;
  obj: TBaseObject;
  obj1, obj2: TBaseObject;
begin
  if Objects = nil then Exit;
  if GameOver then Exit;

  { 점수 업데이트 }
  UpdateScore;

  { 블랙홀 발동 }
  Inc(BlackHoleSpawnTimer);
  if (not IsBlackHoleActive) and (BlackHoleSpawnTimer >= BlackHoleSpawnInterval) then
  begin
    { 화면 중앙에 블랙홀 생성 }
    ActivateBlackHole(Point(Panel1.Width div 2, Panel1.Height div 2));
    BlackHoleSpawnTimer := 0;
  end;

  { 블랙홀 이펙트 발동 }
  UpdateBlackHoleEffect;

  { 배경 초기화 }
  PaintBox1.Canvas.Brush.Color := clBlack;
  PaintBox1.Canvas.FillRect(Rect(0, 0, Panel1.Width, Panel1.Height));

  { 화면에 있는 모든 오브젝트 이동 }
  for i := 0 to Objects.Count - 1 do
  begin
    obj := TBaseObject(Objects[i]);
    obj.Move; // TBaseObject.Move에서 블랙홀/버스트 로직을 처리
  end;

  // 죽은 오브젝트 삭제 처리: 역순으로 순회하며 IsDead가 True인 객체 삭제
  for i := Objects.Count - 1 downto 0 do
  begin
    obj := TBaseObject(Objects[i]);
    if obj.IsDead then
    begin

      Objects.Delete(i);
      obj.Free;
    end;
  end;

  { 마우스 오브젝트를 제외한 다른 오브젝트끼리의 충돌 }
  if not (IsBlackHoleActive or IsBurstActive) then
  begin
    for i := 0 to Objects.Count - 2 do
    begin
      for j := i + 1 to Objects.Count - 1 do
      begin
        Obj1 := TBaseObject(Objects[i]);
        Obj2 := TBaseObject(Objects[j]);

        // ObjD, ObjFollow, ObjMouse는 충돌 무시
        if (Obj1.ObjType = ObjD) or (Obj2.ObjType = ObjD) or
            (Obj1.ObjType = ObjFollow) or (Obj2.ObjType = ObjFollow) or
            (Obj1.ObjType = ObjMouse) or (Obj2.ObjType = ObjMouse) then
          Continue;

        { 충돌한 오브젝트만 선택 (ObjA, ObjB, ObjC 간의 충돌만) }
        if CheckCollision(Obj1, Obj2) then
        begin
          { 양쪽 모두 회전 }
          Obj1.SpeedX := -Obj1.SpeedX;
          Obj1.SpeedY := -Obj1.SpeedY;

          Obj2.SpeedX := -Obj2.SpeedX;
          Obj2.SpeedY := -Obj2.SpeedY;

          { 서로를 살짝식 밀어서 겹치는 상황 방지 }
          Obj1.X := Obj1.X + Obj1.SpeedX;
          Obj1.Y := Obj1.Y + Obj1.SpeedY;
          Obj2.X := Obj2.X + Obj2.SpeedX;
          Obj2.Y := Obj2.Y + Obj2.SpeedY;
        end;
      end;
    end;
  end;

  { 마우스 오브젝트와 다른 오브젝트들 간의 충돌 처리 (ObjD, ObjFollow 포함) }
  if Assigned(MouseFollower) then
  begin
    for i := 0 to Objects.Count - 1 do
    begin
      obj := TBaseObject(Objects[i]);
      if (obj.ObjType <> ObjMouse) then
      begin
        if CheckCollision(MouseFollower, obj) then
        begin
          GameOver := True;
          Timer1.Enabled := False;
          TimerSpawn.Enabled := False;

          ShowMessage('게임 오버!' + sLineBreak + '최종 점수: ' + IntToStr(Score) + sLineBreak + '다시 시작하려면 확인을 누르세요.');
          ResetGame;
          Exit;
        end;
      end;
    end;
  end;

  { 화면에 존재하는 모든 오브젝트 대상 }
  for i := 0 to Objects.Count - 1 do
  begin
    obj := TBaseObject(Objects[i]);

    { 오브젝트 별 색상 지정 }
    case obj.ObjType of
      ObjA: PaintBox1.Canvas.Brush.Color := clRed;
      ObjB: PaintBox1.Canvas.Brush.Color := clGreen;
      ObjC: PaintBox1.Canvas.Brush.Color := clBlue;
      ObjD: PaintBox1.Canvas.Brush.Color := clYellow;
      ObjFollow: PaintBox1.Canvas.Brush.Color := clLime; // ObjFollow 색상
      ObjMouse: PaintBox1.Canvas.Brush.Color := clWhite;  // 마우스 따라오는 흰색 오브젝트
    else
      PaintBox1.Canvas.Brush.Color := clBlack;
    end;

    { 오브젝트 그리기 }
    PaintBox1.Canvas.FillRect(Rect(obj.X, obj.Y, obj.X + obj.Width, obj.Y + obj.Height));
  end;

  { 블랙홀 이펙트 그리기 }
  DrawBlackHoleEffect;

  { 점수 표시 }
  PaintBox1.Canvas.Font.Color := clWhite;
  PaintBox1.Canvas.Font.Size := 20;
  PaintBox1.Canvas.Font.Style := [fsBold];
  PaintBox1.Canvas.Brush.Style := bsClear; // 투명 배경
  PaintBox1.Canvas.TextOut(20, 20, '점수: ' + IntToStr(Score));
  PaintBox1.Canvas.Brush.Style := bsSolid; // 다시 채우기 모드로 복원

  PaintBox1.Canvas.Font.Color := clWhite;
  PaintBox1.Canvas.Font.Size := 20;
  PaintBox1.Canvas.Font.Style := [fsBold];
  PaintBox1.Canvas.Brush.Style := bsClear; // 투명 배경
  PaintBox1.Canvas.TextOut(20, 50, '최고 점수: ' + IntToStr(MaxScore));
  PaintBox1.Canvas.Brush.Style := bsSolid; // 다시 채우기 모드로 복원
end;

end.
