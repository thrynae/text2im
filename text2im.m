function imtext=text2im(text,fontname)
% Generate an image from text (white text on black background).
%
%syntax:
%imtext=text2im(text)
%imtext=text2im(text,font)
%
% text - Char vector or string vector (arrays of either might work). Which
%        characters are allowed is determined by the font, however, all
%        fonts contain the printable and blank characters below 127. Any
%        newline characters are ignored.
% font - Font name as char array. Which fonts are available is dicated by
%        the text2im_load_database function. Currently implemented:
%        - 'cmu_typewriter_text' (default)
%              Supports 365 characters. This is a public domain typeface.
%              [character size = 90x55]
%        - 'cmu_concrete'
%              Supports 364 characters. This is a public domain typeface.
%              [character size = 90x75]
%        - 'ascii'
%              Contains only 94 characters (all printable chars below 127).
%              This typeface was previously published in the text2im()
%              function (FEX:19896 by Tobias Kiessling).
%              [character size = 20x18]
%        - 'droid_sans_mono'
%              Supports 411 characters. Apache License, Version 2.0
%              [character size = 95x51]
%        - 'ibm_plex_mono'
%              Supports 376 characters. SIL Open Font License
%              [character size = 95x51]
%        - 'liberation_mono'
%              Supports 415 characters. GNU General Public License
%              [character size = 95x51]
%        - 'monoid'
%              Supports 398 characters. MIT License
%              [character size = 95x51]
%
% imtext        - Char array containing the text image. The size of each
%                 character is dependent on the font.
%
%The list of included characters is based on a relatively arbitrary
%selection from the pages below.
%https://en.wikipedia.org/wiki/List_of_Unicode_characters
%https://en.wikipedia.org/wiki/Newline#Unicode
%https://en.wikipedia.org/wiki/Whitespace_character#Unicode
%
% Compatibility:
% Matlab: should work on most releases (tested on R2020a(x64), R2015b(x32),
%         R2011a(x64), and R6.5)
% Octave: should work on most versions (tested on 5.1.0 on Windows 10,
%         4.2.2 on Ubuntu, and 4.4.1 on MacOS)
% OS:     Matlab tested on Windows 10 (32bit and 64bit).
%         Octave tested  on Windows 10 (32bit and 64bit) and on a virtual
%         Ubuntu 18.04 LTS (64bit).
%         Should work for Mac.
%
% Version: 1.0.1 [moved to GitHub]
% Date:    2020-05-01
% Author:  H.J. Wisselink
% Licence: CC by-nc-sa 4.0 ( creativecommons.org/licenses/by-nc-sa/4.0 )
% Email=  'h_j_wisselink*alumnus_utwente_nl';
% Real_email = regexprep(Email,{'*','_'},{'@','.'})

if nargin<2,fontname='cmu_typewriter_text';end
[HasGlyph,glyphs,valid]=text2im_load_database(fontname);

%Convert string or char array into numeric array. If this fails, that means
%the input was invalid.
try
    if isa(text,'string')
        %convert string to char (unequal lengths are padded with spaces
        %automatically)
        text=char(text(:));
    end
    text=double(text);%convert to explicit numeric
    if ~all(ismember(text,valid(1,:)))
        %trigger error if any invalid chars are detected
        [1 1] && [1 1]; %#ok
    end
catch
    error('HJW:text2im:InvalidInput',...
        ['The input is invalid or contains symbols that are missing in',...
        ' your font.',char(10),'(all fonts will have the <127 ASCII ',...
        'characters)']) %#ok<CHARTEN>
end

%remove newlines and zero width characters
text=text(ismember(text,HasGlyph));
imtext=cell2mat(reshape(glyphs(text),size(text)));
end
function [HasGlyph,glyphs,valid]=text2im_load_database(fontname,purge)
%The list of included characters is based on a relatively arbitrary
%selection from the pages below.

%types:
% 1: printable (subset of the 'normal' characters with well-defined glyphs)
% 2: blank (spaces and tabs)
% 3: newline (line feed, carriage return, etc)
% 4: zero width (soft hyphen and joining characters)

% An attempt was made to include all of these codepoints:
% printable=sort([33:126 161:172 174:328 330:383 913:929 931:1023 ...
%     8211:8213 8215:8222 8224:8226 8230 8240 8227 8243 8249 8250 8252 ...
%     8254 8260 8266 8352:8383 8448:8527 8592:8703]);
%pages on which this selection is based:
%https://en.wikipedia.org/wiki/List_of_Unicode_characters
%https://en.wikipedia.org/wiki/Newline#Unicode
%https://en.wikipedia.org/wiki/Whitespace_character#Unicode
persistent glyph_database
if nargin~=2,purge=false;end
if purge,glyph_database=[];end
if isempty(glyph_database)
    glyph_database=getpref('HJW',...%author initials as group ID
        ['text2im___',...%function group
        'MATLAB_OCTAVE___',...%affected runtimes
        'glyph_database'],...%preference name
        []);
    if purge,glyph_database=[];end
    if isempty(glyph_database)
        glyph_database=create_pref_struct;
        setpref('HJW',...%author initials as group ID
            ['text2im___',...%function group
            'MATLAB_OCTAVE___',...%affected runtimes
            'glyph_database'],...%preference name
            glyph_database);
    end
end

if nargin>0
    name_list={glyph_database.valid_name};
    idx=find(ismember(name_list,fontname));
    if isempty(idx)
        warning('HJW:text2im:IncorrectFontName',['Font name doesn''t m',...
            'atch any implemented font, reverting to default.'])
        idx=1;
    end
else
    idx=1;
end
S=glyph_database(idx);

blank=[9 32 160 5760 8192:8202 8239 8287];
newlines=[10 11 12 13 133 8232 8233];
zerowidth=[173 8203 8204 8205 8288];

printable=S.printable(:)';
glyphs=cell(max(printable),1);
glyphs(printable)=S.glyphs;
glyphs(blank)={false(size(S.glyphs{1}))};

valid=[printable blank newlines zerowidth;ones(size(printable)),...
    2*ones(size(blank)),3*ones(size(newlines)),4*ones(size(zerowidth))];
HasGlyph=sort([printable blank]);
end
function S=create_pref_struct
S=struct;
font_list={'CMU Typewriter Text','CMU Concrete','ASCII',...
    'Droid Sans Mono','IBM Plex Mono','Liberation Mono','Monoid'};
for n=1:numel(font_list)
    S(n).name=font_list{n};
    S(n).valid_name=strrep(lower(S(n).name),' ','_');
    S(n).url=sprintf('%s%s.png','C:\tmp\text2im_glyphs_',strrep(font_list{n},' ','_'));
    switch S(n).valid_name
        case 'cmu_typewriter_text'
            %20200418093655 for a 55px wide version
            S(n).url=['http://web.archive.org/web/20200418101117im_/',...
                'https://hjwisselink.nl/FEXsubmissiondata/75021-text2im/',...
                'text2im_glyphs_CMU_Typewriter_Text.png'];
        case 'cmu_concrete'
            S(n).url=['http://web.archive.org/web/20200418093550im_/',...
                'https://hjwisselink.nl/FEXsubmissiondata/75021-text2im/',...
                'text2im_glyphs_CMU_Concrete.png'];
        case 'ascii'
            S(n).url=['http://web.archive.org/web/20200418093459im_/',...
                'https://hjwisselink.nl/FEXsubmissiondata/75021-text2im/',...
                'text2im_glyphs_ASCII.png'];
        case 'droid_sans_mono'
            S(n).url=['http://web.archive.org/web/20200418093741im_/',...
                'https://hjwisselink.nl/FEXsubmissiondata/75021-text2im/',...
                'text2im_glyphs_Droid_Sans_Mono.png'];
        case 'ibm_plex_mono'
            S(n).url=['http://web.archive.org/web/20200418093815im_/',...
                'https://hjwisselink.nl/FEXsubmissiondata/75021-text2im/',...
                'text2im_glyphs_IBM_Plex_Mono.png'];
        case 'liberation_mono'
            S(n).url=['http://web.archive.org/web/20200418093840im_/',...
                'https://hjwisselink.nl/FEXsubmissiondata/75021-text2im/',...
                'text2im_glyphs_Liberation_Mono.png'];
        case 'monoid'
            S(n).url=['http://web.archive.org/web/20200418093903im_/',...
                'https://hjwisselink.nl/FEXsubmissiondata/75021-text2im/',...
                'text2im_glyphs_Monoid.png'];
    end
    [S(n).printable,S(n).glyphs]=get_glyphs(S(n));
end
end
function [printable,glyphs]=get_glyphs(S)
%Retrieve glyphs from png masterfile.
%The top line encodes the glyhp height, glyph width, and number of glyphs
%in 20 bits for each number. A column next to each glyph encodes the
%codepoint. The png files that are loaded here were made with the
%text2im_generate_glyphs_from_font function, which has many requirements
%before it works properly. For that reason the png files were also put on
%the Wayback Machine.

IM=download_IM(S.url);
if isempty(IM),IM=get_IM_from_user(S);end

%read row1
sz=bin2dec(char('0'+reshape(IM(1,1:60),20,3)'));

%split into glyphs
dim1=(sz(1))*ones(1,ceil(sz(3)/32));
dim2=(sz(2)+1)*ones(1,32);% +1 to account for the codepoint encoding
c=mat2cell(IM(2:end,:),dim1,dim2);
c=c';c=c(1:sz(3));

glyphs=cell(size(c));
printable=zeros(size(c));
r_=max(1,sz(1)-17);%at most 16 bits are used for the codepoint
for k=1:numel(c)
    glyphs{k}=c{k}(:,2:end);
    printable(k)=bin2dec(char('0'+c{k}(r_:end,1)'));
end
end
function IM=download_IM(url)
for tries=1:3
    try
        IM=imread(url);
        break
    catch
        IM=[];
    end
end
if isempty(IM)
    %As a fallback for when there is something wrong with the Wayback
    %Machine, we can still try loading from hjwisselink.nl instead.
    % remove 'http://web.archive.org/web/yyyymmddhhmmssim_/'
    %         000000000111111111122222222223333333333444444
    %         123456789012345678901234567890123456789012345
    tmp=url(46:end);
    try
        IM=imread(tmp);
    catch
        IM=[];
    end
end
end
function IM=get_IM_from_user(S)
%create a GUI to let the user download and select the file
explanation={'Loading of image failed.','',['You can try again or manu',...
    'ally download the image from the URL below.'],'',['Once you have ',...
    'downloaded the png, click the button and locate the file.']};
menu='menu';if exist('OCTAVE_VERSION', 'builtin'),menu='menubar';end
f=figure(menu,'none','toolbar','none');
uicontrol('Parent',f,'style','text',...
    'Units','Normalized','Position',[0.15 0.75 0.70 0.15],...
    'String',explanation);
uicontrol('Parent',f,'style','edit',...
    'Units','Normalized','Position',[0.15 0.5 0.70 0.15],...
    'String',S.url);
uicontrol('Parent',f,'style','pushbutton',...
    'Units','Normalized','Position',[0.15 0.15 0.70 0.25],...
    'String',sprintf('Select the file for: %s',S.name),...
    'Callback',@select_png);
h=struct('f',f);guidata(f,h)
uiwait(f)
h=guidata(f);
close(f)
IM=imread(fullfile(h.path,h.file));
end
function select_png(obj,e) %#ok<INUSD>
h=guidata(obj);
[h.file,h.path]=uigetfile('text2im_glyphs_*.png');
guidata(obj,h);
uiresume(h.f);
end
