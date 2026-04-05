unit uCompanionData;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

const
  SPECIES_COUNT = 18;
  FRAME_COUNT   = 3;
  EYE_COUNT     = 6;
  HAT_COUNT     = 8;
  RARITY_COUNT  = 5;
  STAT_COUNT    = 5;

  SpeciesNames: array[0..SPECIES_COUNT-1] of string = (
    'duck', 'goose', 'blob', 'cat', 'dragon', 'octopus',
    'owl', 'penguin', 'turtle', 'snail', 'ghost', 'axolotl',
    'capybara', 'cactus', 'robot', 'rabbit', 'mushroom', 'chonk'
  );

  EyeChars: array[0..EYE_COUNT-1] of string = (
    #$C2#$B7,       // ·
    #$E2#$9C#$A6,   // ✦
    #$C3#$97,       // ×
    #$E2#$97#$89,   // ◉
    '@',
    #$C2#$B0        // °
  );

  EyeLabels: array[0..EYE_COUNT-1] of string = (
    'dot', 'star', 'cross', 'circle', 'at', 'degree'
  );

  HatNames: array[0..HAT_COUNT-1] of string = (
    'none', 'crown', 'tophat', 'propeller', 'halo', 'wizard', 'beanie', 'tinyduck'
  );

  HatArt: array[0..HAT_COUNT-1] of string = (
    '',
    '   \^^^/    ',
    '   [___]    ',
    '    -+-     ',
    '   (   )    ',
    '    /^\     ',
    '   (___)    ',
    '    ,>      '
  );

  RarityNames: array[0..RARITY_COUNT-1] of string = (
    'common', 'uncommon', 'rare', 'epic', 'legendary'
  );

  RarityWeights: array[0..RARITY_COUNT-1] of Integer = (
    60, 25, 10, 4, 1
  );

  // Terminal color names from Claude Code
  RarityColorNames: array[0..RARITY_COUNT-1] of string = (
    'inactive', 'success', 'permission', 'autoAccept', 'warning'
  );

  // Hex colors from Claude Code's ink theme (as TColor BGR values)
  RarityTColors: array[0..RARITY_COUNT-1] of LongInt = (
    $00737373,  // common:    grey     #737373
    $004AA316,  // uncommon:  green    #16a34a
    $00EB6325,  // rare:      blue     #2563eb
    $00F65C8B,  // epic:      purple   #8b5cf6
    $0008B3EA   // legendary: gold     #eab308
  );

  // Rarity star display
  RarityStars: array[0..RARITY_COUNT-1] of string = (
    '*', '**', '***', '****', '*****'
  );

  // Hatching system prompt (fD1)
  HATCHING_SYSTEM_PROMPT =
    'You generate coding companions '#$E2#$80#$94' small creatures that live in a ' +
    'developer''s terminal and occasionally comment on their work.'#10#10 +
    'Given a rarity, species, stats, and a handful of inspiration words, invent:'#10 +
    '- A name: ONE word, max 12 characters. Memorable, slightly absurd. No titles, ' +
    'no "the X", no epithets. Think pet name, not NPC name. The inspiration words ' +
    'are loose anchors '#$E2#$80#$94' riff on one, mash two syllables, or just use the vibe. ' +
    'Examples: Pith, Dusker, Crumb, Brogue, Sprocket.'#10 +
    '- A one-sentence personality (specific, funny, a quirk that affects how they''d ' +
    'comment on code '#$E2#$80#$94' should feel consistent with the stats)'#10#10 +
    'Higher rarity = weirder, more specific, more memorable. A legendary should be ' +
    'genuinely strange.'#10 +
    'Don''t repeat yourself '#$E2#$80#$94' every companion should feel distinct.';

  // Inspiration words (oh7) — used during hatching to seed personality generation
  INSPIRATION_WORD_COUNT = 146;
  InspirationWords: array[0..INSPIRATION_WORD_COUNT-1] of string = (
    'thunder','biscuit','void','accordion','moss','velvet','rust','pickle','crumb','whisper',
    'gravy','frost','ember','soup','marble','thorn','honey','static','copper','dusk',
    'sprocket','bramble','cinder','wobble','drizzle','flint','tinsel','murmur','clatter','gloom',
    'nectar','quartz','shingle','tremor','umber','waffle','zephyr','bristle','dapple','fennel',
    'gristle','huddle','kettle','lumen','mottle','nuzzle','pebble','quiver','ripple','sable',
    'thistle','vellum','wicker','yonder','bauble','cobble','doily','fickle','gambit','hubris',
    'jostle','knoll','larder','mantle','nimbus','oracle','plinth','quorum','relic','spindle',
    'trellis','urchin','vortex','warble','xenon','yoke','zenith','alcove','brogue','chisel',
    'dirge','epoch','fathom','glint','hearth','inkwell','jetsam','kiln','lattice','mirth',
    'nook','obelisk','parsnip','quill','rune','sconce','tallow','umbra','verve','wisp',
    'yawn','apex','brine','crag','dregs','etch','flume','gable','husk','ingot',
    'jamb','knurl','loam','mote','nacre','ogle','prong','quip','rind','slat',
    'tuft','vane','welt','yarn','bane','clove','dross','eave','fern','grit',
    'hive','jade','keel','lilt','muse','nape','omen','pith','rook','silt',
    'tome','urge','vex','wane','yew','zest'
  );

  // Fallback name pool (ah7) — used if hatching API fails
  FallbackNames: array[0..5] of string = (
    'Crumpet', 'Soup', 'Pickle', 'Biscuit', 'Moth', 'Gravy'
  );

  StatNames: array[0..STAT_COUNT-1] of string = (
    'DEBUGGING', 'PATIENCE', 'CHAOS', 'WISDOM', 'SNARK'
  );

  // Face templates for narrow/inline display. {E} = eye char.
  FaceTemplates: array[0..SPECIES_COUNT-1] of string = (
    '({E}>',          // duck
    '({E}>',          // goose
    '({E}{E})',        // blob
    '={E}'#$CF#$89'{E}=',  // cat  (ω)
    '<{E}~{E}>',      // dragon
    '~({E}{E})~',      // octopus
    '({E})({E})',      // owl
    '({E}>)',          // penguin
    '[{E}_{E}]',       // turtle
    '{E}(@)',          // snail
    '/{E}{E}\',        // ghost
    '}{E}.{E}{',       // axolotl
    '({E}oo{E})',      // capybara
    '|{E}  {E}|',     // cactus
    '[{E}{E}]',        // robot
    '({E}..{E})',      // rabbit
    '|{E}  {E}|',     // mushroom
    '({E}.{E})'        // chonk
  );

type
  TArtFrame = array[0..4] of string;  // 5 lines per frame
  TArtFrames = array[0..FRAME_COUNT-1] of TArtFrame;

const
  // ============================================================
  //  ASCII ART -- 3 frames per species, 5 lines each
  //  {E} placeholder replaced with eye char at render time
  //  Note: acute accent (') used as backtick substitute
  // ============================================================

  ArtDuck: TArtFrames = (
    ('            ', '    __      ', '  <({E} )___  ', '   (  ._>   ', '    `--''    '),
    ('            ', '    __      ', '  <({E} )___  ', '   (  ._>   ', '    `--''~   '),
    ('            ', '    __      ', '  <({E} )___  ', '   (  .__>  ', '    `--''    ')
  );

  ArtGoose: TArtFrames = (
    ('            ', '     ({E}>    ', '     ||     ', '   _(__)_   ', '    ^^^^    '),
    ('            ', '    ({E}>     ', '     ||     ', '   _(__)_   ', '    ^^^^    '),
    ('            ', '     ({E}>>   ', '     ||     ', '   _(__)_   ', '    ^^^^    ')
  );

  ArtBlob: TArtFrames = (
    ('            ', '   .----.   ', '  ( {E}  {E} )  ', '  (      )  ', '   `----''   '),
    ('            ', '  .------.  ', ' (  {E}  {E}  ) ', ' (        ) ', '  `------''  '),
    ('            ', '    .--.    ', '   ({E}  {E})   ', '   (    )   ', '    `--''    ')
  );

  ArtCat: TArtFrames = (
    ('            ', '   /\_/\    ', '  ( {E}   {E})  ', '  (  '#$CF#$89'  )  ', '  (")_(")   '),
    ('            ', '   /\_/\    ', '  ( {E}   {E})  ', '  (  '#$CF#$89'  )  ', '  (")_(")~  '),
    ('            ', '   /\-/\    ', '  ( {E}   {E})  ', '  (  '#$CF#$89'  )  ', '  (")_(")   ')
  );

  ArtDragon: TArtFrames = (
    ('            ', '  /^\  /^\  ', ' <  {E}  {E}  > ', ' (   ~~   ) ', '  `-vvvv-''  '),
    ('            ', '  /^\  /^\  ', ' <  {E}  {E}  > ', ' (        ) ', '  `-vvvv-''  '),
    ('   ~    ~   ', '  /^\  /^\  ', ' <  {E}  {E}  > ', ' (   ~~   ) ', '  `-vvvv-''  ')
  );

  ArtOctopus: TArtFrames = (
    ('            ', '   .----.   ', '  ( {E}  {E} )  ', '  (______)  ', '  /\/\/\/\  '),
    ('            ', '   .----.   ', '  ( {E}  {E} )  ', '  (______)  ', '  \/\/\/\/  '),
    ('       o    ', '   .----.   ', '  ( {E}  {E} )  ', '  (______)  ', '  /\/\/\/\  ')
  );

  ArtOwl: TArtFrames = (
    ('            ', '   /\  /\   ', '  (({E})({E}))  ', '  (  ><  )  ', '   `----''   '),
    ('            ', '   /\  /\   ', '  (({E})({E}))  ', '  (  ><  )  ', '   .----.   '),
    ('            ', '   /\  /\   ', '  (({E})(-))  ', '  (  ><  )  ', '   `----''   ')
  );

  ArtPenguin: TArtFrames = (
    ('            ', '  .---.     ', '  ({E}>{E})     ', ' /(   )\    ', '  `---''     '),
    ('            ', '  .---.     ', '  ({E}>{E})     ', ' |(   )|    ', '  `---''     '),
    ('  .---.     ', '  ({E}>{E})     ', ' /(   )\    ', '  `---''     ', '   ~ ~      ')
  );

  ArtTurtle: TArtFrames = (
    ('            ', '   _,--._   ', '  ( {E}  {E} )  ', ' /[______]\ ', '  ``    ``  '),
    ('            ', '   _,--._   ', '  ( {E}  {E} )  ', ' /[______]\ ', '   ``  ``   '),
    ('            ', '   _,--._   ', '  ( {E}  {E} )  ', ' /[======]\ ', '  ``    ``  ')
  );

  ArtSnail: TArtFrames = (
    ('            ', ' {E}    .--.  ', '  \  ( @ )  ', '   \_`--''   ', '  ~~~~~~~   '),
    ('            ', ' {E}   .--.   ', '  |  ( @ )  ', '   \_`--''   ', '  ~~~~~~~   '),
    ('            ', ' {E}    .--.  ', '  \  ( @  ) ', '   \_`--''   ', '   ~~~~~~   ')
  );

  ArtGhost: TArtFrames = (
    ('            ', '   .----.   ', '  / {E}  {E} \  ', '  |      |  ', '  ~`~``~`~  '),
    ('            ', '   .----.   ', '  / {E}  {E} \  ', '  |      |  ', '  `~`~~`~`  '),
    ('     ~  ~   ', '   .----.   ', '  / {E}  {E} \  ', '  |      |  ', '  ~~`~~`~~  ')
  );

  ArtAxolotl: TArtFrames = (
    ('            ', '}~(______)~{', '}~({E} .. {E})~{', '  ( .--. )  ', '  (_/  \_)  '),
    ('            ', '~}(______){~', '~}({E} .. {E}){~', '  ( .--. )  ', '  (_/  \_)  '),
    ('            ', '}~(______)~{', '}~({E} .. {E})~{', '  (  --  )  ', '  ~_/  \_~  ')
  );

  ArtCapybara: TArtFrames = (
    ('            ', '  n______n  ', ' ( {E}    {E} ) ', ' (   oo   ) ', '  `------''  '),
    ('            ', '  n______n  ', ' ( {E}    {E} ) ', ' (   Oo   ) ', '  `------''  '),
    ('     ~  ~   ', '  u______n  ', ' ( {E}    {E} ) ', ' (   oo   ) ', '  `------''  ')
  );

  ArtCactus: TArtFrames = (
    ('            ', ' n  ____  n ', ' | |{E}  {E}| | ', ' |_|    |_| ', '   |    |   '),
    ('            ', '     ____   ', '  n |{E}  {E}| n ', '  |_|    |_|', '    |    |  '),
    (' n        n ', ' |  ____  | ', ' | |{E}  {E}| | ', ' |_|    |_| ', '   |    |   ')
  );

  ArtRobot: TArtFrames = (
    ('            ', '   .[||].   ', '  [ {E}  {E} ]  ', '  [ ==== ]  ', '  `------''  '),
    ('            ', '   .[||].   ', '  [ {E}  {E} ]  ', '  [ -==- ]  ', '  `------''  '),
    ('       *    ', '   .[||].   ', '  [ {E}  {E} ]  ', '  [ ==== ]  ', '  `------''  ')
  );

  ArtRabbit: TArtFrames = (
    ('            ', '   (\__/)   ', '  ( {E}  {E} )  ', ' =(  ..  )= ', '  (")__(")  '),
    ('            ', '   (|__/)   ', '  ( {E}  {E} )  ', ' =(  ..  )= ', '  (")__(")  '),
    ('            ', '   (\__/)   ', '  ( {E}  {E} )  ', ' =( .  . )= ', '  (")__(")  ')
  );

  ArtMushroom: TArtFrames = (
    ('            ', ' .-o-OO-o-. ', '(__________)', '   |{E}  {E}|   ', '   |____|   '),
    ('            ', ' .-O-oo-O-. ', '(__________)', '   |{E}  {E}|   ', '   |____|   '),
    ('   . o  .   ', ' .-o-OO-o-. ', '(__________)', '   |{E}  {E}|   ', '   |____|   ')
  );

  ArtChonk: TArtFrames = (
    ('            ', '  /\    /\  ', ' ( {E}    {E} ) ', ' (   ..   ) ', '  `------''  '),
    ('            ', '  /\    /|  ', ' ( {E}    {E} ) ', ' (   ..   ) ', '  `------''  '),
    ('            ', '  /\    /\  ', ' ( {E}    {E} ) ', ' (   ..   ) ', '  `------''~ ')
  );

  // Animation sequence: 0,1,2 = normal frames, -1 = blink (frame 0 with eyes replaced by '-')
  ANIM_SEQ_LEN = 15;
  AnimSequence: array[0..ANIM_SEQ_LEN-1] of Integer = (
    0, 0, 0, 0, 1, 0, 0, 0, -1, 0, 0, 2, 0, 0, 0
  );

  BLINK_FRAME = -1;

  ReadFrames: array[0..4] of string = (
    '1 0 1 0 1 0 ',
    ' 0 1 1 0 0 1',
    '1 1 0 1 0 1 ',
    ' 0 0 1 1 1 0',
    '0 1 0 1 0 0 '
  );

  PetFrames: array[0..4] of string = (
    '   '#$E2#$99#$A5'    '#$E2#$99#$A5'   ',
    '  '#$E2#$99#$A5'  '#$E2#$99#$A5'   '#$E2#$99#$A5'  ',
    ' '#$E2#$99#$A5'   '#$E2#$99#$A5'  '#$E2#$99#$A5'   ',
    #$E2#$99#$A5'  '#$E2#$99#$A5'      '#$E2#$99#$A5' ',
    #$C2#$B7'    '#$C2#$B7'   '#$C2#$B7'  '
  );

function GetSpeciesIndex(const AName: string): Integer;
function GetEyeIndex(const AEye: string): Integer;
function GetHatIndex(const AHat: string): Integer;
function GetRarityIndex(const ARarity: string): Integer;
function GetArtFrame(ASpeciesIdx, AFrameIdx: Integer): TArtFrame;
function RenderFace(ASpeciesIdx: Integer; const AEye: string): string;
function SubstituteEyes(const ALine, AEye: string): string;

implementation

function GetSpeciesIndex(const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to SPECIES_COUNT - 1 do
    if LowerCase(AName) = SpeciesNames[I] then
      Exit(I);
  Result := -1;
end;

function GetEyeIndex(const AEye: string): Integer;
var
  I: Integer;
begin
  for I := 0 to EYE_COUNT - 1 do
    if AEye = EyeChars[I] then
      Exit(I);
  Result := -1;
end;

function GetHatIndex(const AHat: string): Integer;
var
  I: Integer;
begin
  for I := 0 to HAT_COUNT - 1 do
    if LowerCase(AHat) = HatNames[I] then
      Exit(I);
  Result := -1;
end;

function GetRarityIndex(const ARarity: string): Integer;
var
  I: Integer;
begin
  for I := 0 to RARITY_COUNT - 1 do
    if LowerCase(ARarity) = RarityNames[I] then
      Exit(I);
  Result := -1;
end;

function GetArtFrame(ASpeciesIdx, AFrameIdx: Integer): TArtFrame;
var
  F: Integer;
begin
  F := AFrameIdx mod FRAME_COUNT;
  case ASpeciesIdx of
    0:  Result := ArtDuck[F];
    1:  Result := ArtGoose[F];
    2:  Result := ArtBlob[F];
    3:  Result := ArtCat[F];
    4:  Result := ArtDragon[F];
    5:  Result := ArtOctopus[F];
    6:  Result := ArtOwl[F];
    7:  Result := ArtPenguin[F];
    8:  Result := ArtTurtle[F];
    9:  Result := ArtSnail[F];
    10: Result := ArtGhost[F];
    11: Result := ArtAxolotl[F];
    12: Result := ArtCapybara[F];
    13: Result := ArtCactus[F];
    14: Result := ArtRobot[F];
    15: Result := ArtRabbit[F];
    16: Result := ArtMushroom[F];
    17: Result := ArtChonk[F];
  else
    begin
      Result[0] := '            ';
      Result[1] := '   (???)    ';
      Result[2] := '   (   )    ';
      Result[3] := '   (   )    ';
      Result[4] := '            ';
    end;
  end;
end;

function SubstituteEyes(const ALine, AEye: string): string;
begin
  Result := StringReplace(ALine, '{E}', AEye, [rfReplaceAll]);
end;

function RenderFace(ASpeciesIdx: Integer; const AEye: string): string;
begin
  if (ASpeciesIdx >= 0) and (ASpeciesIdx < SPECIES_COUNT) then
    Result := SubstituteEyes(FaceTemplates[ASpeciesIdx], AEye)
  else
    Result := '(?)';
end;

end.
