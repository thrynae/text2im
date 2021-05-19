function imtext=text2im(text,fontname)
% Generate an image from text (white text on black background).
%
%syntax:
%imtext=text2im(text)
%imtext=text2im(text,font)
%
% text - The text to be converted can be supplied as char, string, or cellstr. Which characters are
%        allowed is determined by the font. However, all fonts contain the printable and blank
%        characters below 127. Any non-standard newline characters are ignored (i.e. LF/CR/CRLF are
%        parsed as newline). Non-scalar inputs (or non-row vector inputs in the case of char) are
%        allowed, but might not return the desired result.
% font - Font name as char array. Which fonts are available is dictated by the
%        text2im_load_database function. Currently implemented:
%        - 'cmu_typewriter_text' (default)
%              Supports 365 characters. This is a public domain typeface.
%              [character size = 90x55]
%        - 'cmu_concrete'
%              Supports 364 characters. This is a public domain typeface.
%              [character size = 90x75]
%        - 'ascii'
%              Contains only 94 characters (all printable chars below 127). This typeface was
%              previously published in the text2im() function (FEX:19896 by Tobias Kiessling).
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
% imtext - A char array containing the text image. The size is dependent on the font.
%
%The list of included characters is based on a relatively arbitrary selection from the pages below.
%https://en.wikipedia.org/wiki/List_of_Unicode_characters
%https://en.wikipedia.org/wiki/Newline#Unicode
%https://en.wikipedia.org/wiki/Whitespace_character#Unicode
%
%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%
%|                                                                         |%
%|  Version: 1.1.0                                                         |%
%|  Date:    2021-05-19                                                    |%
%|  Author:  H.J. Wisselink                                                |%
%|  Licence: CC by-nc-sa 4.0 ( creativecommons.org/licenses/by-nc-sa/4.0 ) |%
%|  Email = 'h_j_wisselink*alumnus_utwente_nl';                            |%
%|  Real_email = regexprep(Email,{'*','_'},{'@','.'})                      |%
%|                                                                         |%
%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%
%
% Tested on several versions of Matlab (ML 6.5 and onward) and Octave (4.4.1 and onward), and on
% multiple operating systems (Windows/Ubuntu/MacOS). For the full test matrix, see the HTML doc.
% Compatibility considerations:
% - Multiline inputs may have more trailing blank elements than intended. This is especially true
%   for characters encoded with multiple elements (>127 for Octave and >65535 for Matlab).

if nargin<2,fontname='cmu_typewriter_text';end
[HasGlyph,glyphs,valid]=text2im_load_database(fontname);

ConvertFromUTF16=ifversion('>',0,'Octave','<',0);

%Convert string or char array into numeric array. If this fails, that means the input was invalid.
try
    %Convert to uint32 Unicode codepoints.
    c=cellstr(text);%This will deal with the string datatype as well
    for n=1:numel(c)
        row=c{n};
        if ConvertFromUTF16
            %Get the Unicode code points from the UTF-16 encoding.
            row=UTF16_to_unicode(row);%Returns uint32.
        else
            %Get the Unicode code points from the UTF-8 encoding.
            row=UTF8_to_unicode(row);%Returns uint32.
        end
        c{n}=row;
    end
    
    %Split over standard newlines(LF/CR/CRLF). We can't use regexp() or split() here, as the text
    %is uint32, not char.
    for n=1:numel(c)
        %This function returns a cell array with 1xN elements of the input data type.
        c{n}=char2cellstr(c{n});
    end
    c=vertcat(c{:});
    
    %Remove newlines and zero width characters.
    for n=1:numel(c)
        c{n}=c{n}(ismember(c{n},HasGlyph));
    end
    
    %Pad with spaces if needed
    len=cellfun('prodofsize',c);maxlen=max(len);
    for n=find(len<maxlen).'
        c{n}((end+1):maxlen)=32;
    end
    text=cell2mat(c);
    if ~all(ismember(text,valid(1,:)))
        error('invalid char detected')%Trigger error if any invalid chars are detected.
    end
catch
    error('HJW:text2im:InvalidInput',...
        ['The input is invalid or contains symbols that are missing in your font.',char(10),...
        '(all fonts will have the <127 ASCII characters)']) %#ok<CHARTEN>
end

%Index into the glyph database and reshape to the ouput shape before unwrapping from the cells.
imtext=cell2mat(reshape(glyphs(text),size(text)));
end
function out=bsxfun_plus(in1,in2)
%Implicit expansion for plus(), but without any input validation.
try
    out=in1+in2;
catch
    try
        out=bsxfun(@plus,in1,in2);
    catch
        sz1=size(in1);                    sz2=size(in2);
        in1=repmat(in1,max(1,sz2./sz1));  in2=repmat(in2,max(1,sz1./sz2));
        out=in1+in2;
    end
end
end
function c=char2cellstr(str,LineEnding)
%Split char or uint32 vector to cell (1 cell element per line). Default splits are for CRLF/CR/LF.
%The input data type is preserved.
%
%Since the largest valid Unicode codepoint is 0x10FFFF (i.e. 21 bits), all values will fit in an
%int32 as well. This is used internally to deal with different newline conventions.
%
%The second input is a cellstr containing patterns that will be considered as newline encodings.
%This will not be checked for any overlap and will be processed sequentially.

returnChar=isa(str,'char');
str=int32(str);%convert to signed, this should not crop any valid Unicode codepoints.

if nargin<2
    %Replace CRLF, CR, and LF with -10 (in that order). That makes sure that all valid encodings of
    %newlines are replaced with the same value. This should even handle most cases of files that
    %mix the different styles, even though such mixing should never occur in a properly encoded
    %file. This considers LFCR as two line endings.
    if any(str==13)
        str=PatternReplace(str,int32([13 10]),int32(-10));
        str(str==13)=-10;
    end
    str(str==10)=-10;
else
    for n=1:numel(LineEnding)
        str=PatternReplace(str,int32(LineEnding{n}),int32(-10));
    end
end

%Split over newlines.
newlineidx=[0 find(str==-10) numel(str)+1];
c=cell(numel(newlineidx)-1,1);
for n=1:numel(c)
    s1=(newlineidx(n  )+1);
    s2=(newlineidx(n+1)-1);
    c{n}=str(s1:s2);
end

%Return to the original data type.
if returnChar
    for n=1:numel(c),c{n}=  char(c{n});end
else
    for n=1:numel(c),c{n}=uint32(c{n});end
end
end
function error_(options,varargin)
%Print an error to the command window, a file and/or the String property of an object.
%The error will first be written to the file and object before being actually thrown.
%
%Apart from controlling the way an error is written, you can also run a specific function. The
%'fcn' field of the options must be a struct (scalar or array) with two fields: 'h' with a function
%handle, and 'data' with arbitrary data passed as third input. These functions will be run with
%'error' as first input. The second input is a struct with identifier, message, and stack as
%fields. This function will be run with feval (meaning the function handles can be replaced with
%inline functions or anonymous functions).
%
%The intention is to allow replacement of every error(___) call with error_(options,___).
%
% NB: the error trace that is written to a file or object may differ from the trace displayed by
% calling the builtin error function. This was only observed when evaluating code sections.
%
%options.boolean.con: if true throw error with rethrow()
%options.fid:         file identifier for fprintf (array input will be indexed)
%options.boolean.fid: if true print error to file
%options.obj:         handle to object with String property (array input will be indexed)
%options.boolean.obj: if true print error to object (options.obj)
%options.fcn          struct (array input will be indexed)
%options.fcn.h:       handle of function to be run
%options.fcn.data:    data passed as third input to function to be run (optional)
%options.boolean.fnc: if true the function(s) will be run
%
%syntax:
%  error_(options,msg)
%  error_(options,msg,A1,...,An)
%  error_(options,id,msg)
%  error_(options,id,msg,A1,...,An)
%  error_(options,ME)               %equivalent to rethrow(ME)
%
%examples options struct:
%  % Write to a log file:
%  opts=struct;opts.fid=fopen('log.txt','wt');
%  % Display to a status window and bypass the command window:
%  opts=struct;opts.boolean.con=false;opts.obj=uicontrol_object_handle;
%  % Write to 2 log files:
%  opts=struct;opts.fid=[fopen('log2.txt','wt') fopen('log.txt','wt')];

persistent this_fun
if isempty(this_fun),this_fun=func2str(@error_);end

%Parse options struct.
if isempty(options),options=struct;end%allow empty input to revert to default
options=parse_warning_error_redirect_options(options);
[id,msg,stack,trace]=parse_warning_error_redirect_inputs(varargin{:});
ME=struct('identifier',id,'message',msg,'stack',stack);

%Print to object.
if options.boolean.obj
    msg_=msg;while msg_(end)==10,msg_(end)='';end%Crop trailing newline.
    if any(msg_==10)  % Parse to cellstr and prepend 'Error: '.
        msg_=char2cellstr(['Error: ' msg_]);
    else              % Only prepend 'Error: '.
        msg_=['Error: ' msg_];
    end
    for OBJ=options.obj(:).'
        try set(OBJ,'String',msg_);catch,end
    end
end

%Print to file.
if options.boolean.fid
    for FID=options.fid(:).'
        try fprintf(FID,'Error: %s\n%s',msg,trace);catch,end
    end
end

%Run function.
if options.boolean.fcn
    if ismember(this_fun,{stack.name})
        %To prevent an infinite loop, trigger an error.
        error('prevent recursion')
    end
    for FCN=options.fcn(:).'
        if isfield(FCN,'data')
            try feval(FCN.h,'error',ME,FCN.data);catch,end
        else
            try feval(FCN.h,'error',ME);catch,end
        end
    end
end

%Actually throw the error.
rethrow(ME)
end
function flag=get_MatFileFlag
%This returns '-mat' on Octave (and on pre-v7 Matlab) and '-v6' on Matlab.
%The goal is to allow saving a mat file that can be read on all Matlab and Octave releases.
persistent MatFileFlag
if isempty(MatFileFlag)
    %The ifversion function could be used here instead, but since we only need to find out if we're
    %running pre-v7 Matlab or Octave some simpler logic is enough.
    octave=exist('OCTAVE_VERSION', 'builtin');
    v_num=version;
    ind=min([numel(v_num) strfind(v_num,'.')]);
    v_num=str2double(v_num(1:(ind-1)));%only main version
    if octave || v_num<7
        MatFileFlag='-mat';
    else
        MatFileFlag='-v6';
    end
end
flag=MatFileFlag;
end
function [str,stack]=get_trace(skip_layers,stack)
if nargin==0,skip_layers=1;end
if nargin<2, stack=dbstack;end
stack(1:skip_layers)=[];

%Parse the ML6.5 style of dbstack (the name field includes full file location).
if ~isfield(stack,'file')
    for n=1:numel(stack)
        tmp=stack(n).name;
        if strcmp(tmp(end),')')
            %Internal function.
            ind=strfind(tmp,'(');
            name=tmp( (ind(end)+1):(end-1) );
            file=tmp(1:(ind(end)-2));
        else
            file=tmp;
            [ignore,name]=fileparts(tmp); %#ok<ASGLU>
        end
        [ignore,stack(n).file]=fileparts(file); %#ok<ASGLU>
        stack(n).name=name;
    end
end

%Parse Octave style of dbstack (the file field includes full file location).
persistent IsOctave,if isempty(IsOctave),IsOctave=exist('OCTAVE_VERSION','builtin');end
if IsOctave
    for n=1:numel(stack)
        [ignore,stack(n).file]=fileparts(stack(n).file); %#ok<ASGLU>
    end
end

%Create the char array with a (potentially) modified stack.
s=stack;
c1='>';
str=cell(1,numel(s)-1);
for n=1:numel(s)
    [ignore_path,s(n).file,ignore_ext]=fileparts(s(n).file); %#ok<ASGLU>
    if n==numel(s),s(n).file='';end
    if strcmp(s(n).file,s(n).name),s(n).file='';end
    if ~isempty(s(n).file),s(n).file=[s(n).file '>'];end
    str{n}=sprintf('%c In %s%s (line %d)\n',c1,s(n).file,s(n).name,s(n).line);
    c1=' ';
end
str=horzcat(str{:});
end
function [f,status]=GetWritableFolder(varargin)
%Return a folder with write permission.
% If the output folder doesn't already exist, this function will attempt to create it. This
% function should provide a reliable and repeatable location to write files.
%
% Syntax:
% f=GetWritableFolder
% [f,status]=GetWritableFolder
% [__]=GetWritableFolder(Name,Value)
% [__]=GetWritableFolder(optionstruct)
% 
% Name,Value parameters:
%    ForceStatus     : Retrieve the path corresponding to the status value (default=0;).
%                      (0:auto-determine, 1:AddOn, 2:tempdir, 3:pwd)
%    ErrorOnNotFound : Throw an error when failing to find a writeable folder (default=true;).
%
%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%
%|                                                                         |%
%|  Version: 1.0.0                                                         |%
%|  Date:    2021-02-19                                                    |%
%|  Author:  H.J. Wisselink                                                |%
%|  Licence: CC by-nc-sa 4.0 ( creativecommons.org/licenses/by-nc-sa/4.0 ) |%
%|  Email = 'h_j_wisselink*alumnus_utwente_nl';                            |%
%|  Real_email = regexprep(Email,{'*','_'},{'@','.'})                      |%
%|                                                                         |%
%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%
%
% Tested on several versions of Matlab (ML 6.5 and onward) and Octave (4.4.1 and onward), and on
% multiple operating systems (Windows/Ubuntu/MacOS). For the full test matrix, see the HTML doc.
% Compatibility considerations:
% - The path returned with status=1 is mostly the same as the addonpath for most releases. Although
%   it is not correct for all release/OS combinations, it should still work. If you have a managed
%   account, this might result in strange behavior.

[success,options,ME]=GetWritableFolder_parse_inputs(varargin{:});
if ~success
    rethrow(ME)
else
    [ForceStatus,ErrorOnNotFound,root_folder_list]=deal(options.ForceStatus,...
        options.ErrorOnNotFound,options.root_folder_list);
end
root_folder_list{end}=pwd;%Set this default here to avoid storing it in a persistent.
if ForceStatus
    status=ForceStatus;f=fullfile(root_folder_list{status},'PersistentFolder');
    try if ~exist(f,'dir'),mkdir(f);end,catch,end
    return
end

%Option 1: use a folder similar to the AddOn Manager.
status=1;f=root_folder_list{status};
try if ~exist(f,'dir'),mkdir(f);end,catch,end
if ~TestFolderWritePermission(f)
    % If the Add-On path is not writable, return the tempdir. It will not be persistent, but it
    % will be writable.
    status=2;f=root_folder_list{status};
    try if ~exist(f,'dir'),mkdir(f);end,catch,end
    if ~TestFolderWritePermission(f)
        % The tempdir should always be writable, but if for some reason it isn't: return the pwd.
        status=3;f=root_folder_list{status};
    end
end

%Add 'PersistentFolder' to whichever path was determined above.
f=fullfile(f,'PersistentFolder');
try if ~exist(f,'dir'),mkdir(f);end,catch,end

if ~TestFolderWritePermission(f)
    %Apparently even the pwd isn't writable, so we will either return an error, or a fail state.
    if ErrorOnNotFound
        error('HJW:GetWritableFolder:NoWritableFolder',...
            'This function was unable to find a folder with write permissions.')
    else
        status=0;f='';
    end
end
end
function [success,options,ME]=GetWritableFolder_parse_inputs(varargin)
%Parse the inputs of the GetWritableFolder function.
% This function returns a success flag, the parsed options, and an ME struct.
% As input, the options should either be entered as a struct or as Name,Value pairs. Missing fields
% are filled from the default.

%Pre-assign outputs.
success=false;
options=struct;
ME=struct('identifier','','message','');

persistent default
if isempty(default)
    %Set defaults for options.
    default.ForceStatus=false;
    default.ErrorOnNotFound=false;
    default.root_folder_list={...
        GetPseudoAddonpath;
        fullfile(tempdir,'MATLAB');
        ''};%Overwrite this last element with pwd when called.
end
%The required inputs are checked, so now we need to return the default options if there are no
%further inputs.
if nargin==2
    options=default;
    success=true;
    return
end

%Test the optional inputs.
struct_input=       nargin   ==1 && isa(varargin{1},'struct');
NameValue_input=mod(nargin,2)==0 && all(...
    cellfun('isclass',varargin(1:2:end),'char'  ) | ...
    cellfun('isclass',varargin(1:2:end),'string')   );
if ~( struct_input || NameValue_input )
    ME.message=['The input is expected to be either a struct, ',char(10),...
        'or consist of Name,Value pairs.']; %#ok<CHARTEN>
    ME.identifier='HJW:GetWritableFolder:incorrect_input_options';
    return
end
if NameValue_input
    %Convert the Name,Value to a struct.
    for n=1:2:numel(varargin)
        try
            options.(varargin{n})=varargin{n+1};
        catch
            ME.message='Parsing of Name,Value pairs failed.';
            ME.identifier='HJW:GetWritableFolder:incorrect_input_NameValue';
            return
        end
    end
else
    options=varargin{1};
end
fn=fieldnames(options);
for k=1:numel(fn)
    curr_option=fn{k};
    item=options.(curr_option);
    ME.identifier=['HJW:GetWritableFolder:incorrect_input_opt_' lower(curr_option)];
    switch curr_option
        case 'ForceStatus'
            try
                if ~isa(default.root_folder_list{item},'char')
                    %This ensures an error for item=[true false true]; as well.
                    error('the indexing must have failed, trigger error')
                end
            catch
                ME.message=sprintf('Invalid input: expected a scalar integer between 1 and %d.',...
                    numel(default.root_folder_list));
                return
            end
        case 'ErrorOnNotFound'
            [passed,options.ErrorOnNotFound]=test_if_scalar_logical(item);
            if ~passed
                ME.message='ErrorOnNotFound should be either true or false.';
                return
            end
        otherwise
            ME.message=sprintf('Name,Value pair not recognized: %s.',curr_option);
            ME.identifier='HJW:GetWritableFolder:incorrect_input_NameValue';
            return
    end
end

%Fill any missing fields.
fn=fieldnames(default);
for k=1:numel(fn)
    if ~isfield(options,fn(k))
        options.(fn{k})=default.(fn{k});
    end
end
success=true;ME=[];
end
function f=GetPseudoAddonpath
% This is mostly the same as the addonpath. Technically this is not correct for all release/OS
% combinations and the code below should be used:
%     addonpath='';
%     try s = Settings;addonpath=get(s.matlab.addons,'InstallationFolder');end %#ok<TRYNC>
%     try s = Settings;addonpath=get(s.matlab.apps,'AppsInstallFolder');end %#ok<TRYNC>
%     try s = settings;addonpath=s.matlab.addons.InstallationFolder.ActiveValue;end %#ok<TRYNC>
%
% However, this returns an inconsistent output:
%     R2011a:         <pref doesn't exist>
%     R2015a Ubuntu  $HOME/Documents/MATLAB/Apps
%            Windows %HOMEPATH%\MATLAB\Apps
%     R2018a Ubuntu  $HOME/Documents/MATLAB/Add-Ons
%            Windows %HOMEPATH%\MATLAB\Add-Ons
%     R2020a Windows %APPDATA%\MathWorks\MATLAB Add-Ons
%
% To make the target folder consistent, only one of these options is chosen.
if ispc
    [ignore,appdata]=system('echo %APPDATA%');appdata(appdata<14)=''; %#ok<ASGLU> (remove LF/CRLF)
    f=fullfile(appdata,'MathWorks','MATLAB Add-Ons');
else
    [ignore,home_dir]=system('echo $HOME');home_dir(home_dir<14)=''; %#ok<ASGLU> (remove LF/CRLF)
    f=fullfile(home_dir,'Documents','MATLAB','Add-Ons');
end
end
function tf=ifversion(test,Rxxxxab,Oct_flag,Oct_test,Oct_ver)
%Determine if the current version satisfies a version restriction
%
% To keep the function fast, no input checking is done. This function returns a NaN if a release
% name is used that is not in the dictionary.
%
% Syntax:
% tf=ifversion(test,Rxxxxab)
% tf=ifversion(test,Rxxxxab,'Octave',test_for_Octave,v_Octave)
%
% Output:
% tf       - If the current version satisfies the test this returns true.
%            This works similar to verLessThan.
%
% Inputs:
% Rxxxxab - Char array containing a release description (e.g. 'R13', 'R14SP2' or 'R2019a') or the
%           numeric version.
% test    - Char array containing a logical test. The interpretation of this is equivalent to
%           eval([current test Rxxxxab]). For examples, see below.
%
% Examples:
% ifversion('>=','R2009a') returns true when run on R2009a or later
% ifversion('<','R2016a') returns true when run on R2015b or older
% ifversion('==','R2018a') returns true only when run on R2018a
% ifversion('==',9.9) returns true only when run on R2020b
% ifversion('<',0,'Octave','>',0) returns true only on Octave
% ifversion('<',0,'Octave','>=',6) returns true only on Octave 6 and higher
%
% The conversion is based on a manual list and therefore needs to be updated manually, so it might
% not be complete. Although it should be possible to load the list from Wikipedia, this is not
% implemented.
%
%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%
%|                                                                         |%
%|  Version: 1.0.6                                                         |%
%|  Date:    2021-03-11                                                    |%
%|  Author:  H.J. Wisselink                                                |%
%|  Licence: CC by-nc-sa 4.0 ( creativecommons.org/licenses/by-nc-sa/4.0 ) |%
%|  Email = 'h_j_wisselink*alumnus_utwente_nl';                            |%
%|  Real_email = regexprep(Email,{'*','_'},{'@','.'})                      |%
%|                                                                         |%
%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%/%
%
% Tested on several versions of Matlab (ML 6.5 and onward) and Octave (4.4.1 and onward), and on
% multiple operating systems (Windows/Ubuntu/MacOS). For the full test matrix, see the HTML doc.
% Compatibility considerations:
% - This is expected to work on all releases.

%The decimal of the version numbers are padded with a 0 to make sure v7.10 is larger than v7.9.
%This does mean that any numeric version input needs to be adapted. multiply by 100 and round to
%remove the potential for float rounding errors.
%Store in persistent for fast recall (don't use getpref, as that is slower than generating the
%variables and makes updating this function harder).
persistent  v_num v_dict octave
if isempty(v_num)
    %test if Octave is used instead of Matlab
    octave=exist('OCTAVE_VERSION', 'builtin');
    
    %get current version number
    v_num=version;
    ii=strfind(v_num,'.');if numel(ii)~=1,v_num(ii(2):end)='';ii=ii(1);end
    v_num=[str2double(v_num(1:(ii-1))) str2double(v_num((ii+1):end))];
    v_num=v_num(1)+v_num(2)/100;v_num=round(100*v_num);
    
    %get dictionary to use for ismember
    v_dict={...
        'R13' 605;'R13SP1' 605;'R13SP2' 605;'R14' 700;'R14SP1' 700;'R14SP2' 700;
        'R14SP3' 701;'R2006a' 702;'R2006b' 703;'R2007a' 704;'R2007b' 705;
        'R2008a' 706;'R2008b' 707;'R2009a' 708;'R2009b' 709;'R2010a' 710;
        'R2010b' 711;'R2011a' 712;'R2011b' 713;'R2012a' 714;'R2012b' 800;
        'R2013a' 801;'R2013b' 802;'R2014a' 803;'R2014b' 804;'R2015a' 805;
        'R2015b' 806;'R2016a' 900;'R2016b' 901;'R2017a' 902;'R2017b' 903;
        'R2018a' 904;'R2018b' 905;'R2019a' 906;'R2019b' 907;'R2020a' 908;
        'R2020b' 909;'R2021a' 910};
end

if octave
    if nargin==2
        warning('HJW:ifversion:NoOctaveTest',...
            ['No version test for Octave was provided.',char(10),...
            'This function might return an unexpected outcome.']) %#ok<CHARTEN>
        if isnumeric(Rxxxxab)
            v=0.1*Rxxxxab+0.9*fix(Rxxxxab);v=round(100*v);
        else
            L=ismember(v_dict(:,1),Rxxxxab);
            if sum(L)~=1
                warning('HJW:ifversion:NotInDict',...
                    'The requested version is not in the hard-coded list.')
                tf=NaN;return
            else
                v=v_dict{L,2};
            end
        end
    elseif nargin==4
        % Undocumented shorthand syntax: skip the 'Octave' argument.
        [test,v]=deal(Oct_flag,Oct_test);
        % Convert 4.1 to 401.
        v=0.1*v+0.9*fix(v);v=round(100*v);
    else
        [test,v]=deal(Oct_test,Oct_ver);
        % Convert 4.1 to 401.
        v=0.1*v+0.9*fix(v);v=round(100*v);
    end
else
    % Convert R notation to numeric and convert 9.1 to 901.
    if isnumeric(Rxxxxab)
        v=0.1*Rxxxxab+0.9*fix(Rxxxxab);v=round(100*v);
    else
        L=ismember(v_dict(:,1),Rxxxxab);
        if sum(L)~=1
            warning('HJW:ifversion:NotInDict',...
                'The requested version is not in the hard-coded list.')
            tf=NaN;return
        else
            v=v_dict{L,2};
        end
    end
end
switch test
    case '==', tf= v_num == v;
    case '<' , tf= v_num <  v;
    case '<=', tf= v_num <= v;
    case '>' , tf= v_num >  v;
    case '>=', tf= v_num >= v;
end
end
function [id,msg,stack,trace]=parse_warning_error_redirect_inputs(varargin)
if nargin==1
    %  error_(options,msg)
    %  error_(options,ME)
    if isa(varargin{1},'struct') || isa(varargin{1},'MException')
        ME=varargin{1};
        try
            stack=ME.stack;%Use the original call stack if possible.
            trace=get_trace(0,stack);
        catch
            [trace,stack]=get_trace(3);
        end
        id=ME.identifier;
        msg=ME.message;
        pat='Error using <a href="matlab:matlab.internal.language.introspective.errorDocCallback(';
        %This pattern may occur when using try error(id,msg),catch,ME=lasterror;end instead of
        %catching the MException with try error(id,msg),catch ME,end.
        %This behavior is not stable enough to robustly check for it, but it only occurs with
        %lasterror, so we can use that.
        if isa(ME,'struct') && numel(msg)>numel(pat) && strcmp(pat,msg(1:numel(pat)))
            %Strip the first line (which states 'error in function (line)', instead of only msg).
            msg(1:find(msg==10,1))='';
        end
    else
        [trace,stack]=get_trace(3);
        [id,msg]=deal('',varargin{1});
    end
else
    [trace,stack]=get_trace(3);
    if ~isempty(strfind(varargin{1},'%')) %The id can't contain a percent symbol.
        %  error_(options,msg,A1,...,An)
        id='';
        A1_An=varargin(2:end);
        msg=sprintf(varargin{1},A1_An{:});
    else
        %  error_(options,id,msg)
        %  error_(options,id,msg,A1,...,An)
        id=varargin{1};
        msg=varargin{2};
        if nargin>3
            A1_An=varargin(3:end);
            msg=sprintf(msg,A1_An{:});
        end
    end
end
end
function options=parse_warning_error_redirect_options(options)
%Fill the struct:
%options.boolean.con (this field is ignored in error_)
%options.boolean.fid
%options.boolean.obj
%options.boolean.fcn
if ~isfield(options,'boolean'),options.boolean=struct;end
if ~isfield(options.boolean,'con') || isempty(options.boolean.con)
    options.boolean.con=false;
end
if ~isfield(options.boolean,'fid') || isempty(options.boolean.fid)
    options.boolean.fid=isfield(options,'fid');
end
if ~isfield(options.boolean,'obj') || isempty(options.boolean.obj)
    options.boolean.obj=isfield(options,'obj');
end
if ~isfield(options.boolean,'fcn') || isempty(options.boolean.fcn)
    options.boolean.fcn=isfield(options,'fcn');
end
end
function out=PatternReplace(in,pattern,rep)
%Functionally equivalent to strrep, but extended to more data types.
out=in(:)';
if numel(pattern)==0
    L=false(size(in));
elseif numel(rep)>numel(pattern)
    error('not implemented (padding required)')
else
    L=true(size(in));
    for n=1:numel(pattern)
        k=find(in==pattern(n));
        k=k-n+1;k(k<1)=[];
        %Now k contains the indices of the beginning of each match.
        L2=false(size(L));L2(k)=true;
        L= L & L2;
        if ~any(L),break,end
    end
end
k=find(L);
if ~isempty(k)
    for n=1:numel(rep)
        out(k+n-1)=rep(n);
    end
    if numel(rep)==0,n=0;end
    if numel(pattern)>n
        k=k(:);%Enforce direction.
        remove=(n+1):numel(pattern);
        idx=bsxfun_plus(k,remove-1);
        out(idx(:))=[];
    end
end
end
function [isLogical,val]=test_if_scalar_logical(val)
%Test if the input is a scalar logical or convertible to it.
%The char and string test are not case sensitive.
%(use the first output to trigger an input error, use the second as the parsed input)
%
% Allowed values:
%- true or false
%- 1 or 0
%- 'on' or 'off'
%- matlab.lang.OnOffSwitchState.on or matlab.lang.OnOffSwitchState.off
%- 'enable' or 'disable'
%- 'enabled' or 'disabled'
persistent states
if isempty(states)
    states={true,false;...
        1,0;...
        'on','off';...
        'enable','disable';...
        'enabled','disabled'};
    try
        states(end+1,:)=eval('{"on","off"}');
    catch
    end
end
isLogical=true;
try
    if isa(val,'char') || isa(val,'string')
        try val=lower(val);catch,end
    end
    for n=1:size(states,1)
        for m=1:2
            if isequal(val,states{n,m})
                val=states{1,m};return
            end
        end
    end
    if isa(val,'matlab.lang.OnOffSwitchState')
        val=logical(val);return
    end
catch
end
isLogical=false;
end
function tf=TestFolderWritePermission(f)
%Returns true if the folder exists and allows Matlab to write files.
%An empty input will generally test the pwd.
%
%examples:
%  fn='foo.txt';if ~TestFolderWritePermission(fileparts(fn)),error('can''t write!'),end

if ~( isempty(f) || exist(f,'dir') )
    tf=false;return
end

fn='';
while isempty(fn) || exist(fn,'file')
    %Generate a random file name, making sure not to overwrite any existing file.
    %This will try to create a file without an extension.
    [ignore,fn]=fileparts(tmpname('write_permission_test_','.txt')); %#ok<ASGLU>
    fn=fullfile(f,fn);
end
try
    %Test write permission.
    fid=fopen(fn,'w');fprintf(fid,'test');fclose(fid);
    delete(fn);
    tf=true;
catch
    %Attempt to clean up.
    if exist(fn,'file'),try delete(fn);catch,end,end
    tf=false;
end
end
function S=text2im_create_pref_struct(varargin)
%Supplying an input will trigger the GUI.
S=struct;
font_list={'CMU Typewriter Text','CMU Concrete','ASCII',...
    'Droid Sans Mono','IBM Plex Mono','Liberation Mono','Monoid'};
for n=1:numel(font_list)
    S(n).name=font_list{n};
    S(n).valid_name=strrep(lower(S(n).name),' ','_');
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
        otherwise
            S(n).url=fullfile(tempdir,['text2im_glyphs_',strrep(font_list{n},' ','_'),'.png']);
    end
    [S(n).printable,S(n).glyphs]=text2im__get_glyphs(S(n),varargin{:});
end
end
function [printable,glyphs]=text2im__get_glyphs(S,varargin)
%Retrieve glyphs from png masterfile.
%The top line encodes the glyph height, glyph width, and number of glyphs in 20 bits for each
%number. A column next to each glyph encodes the codepoint. The png files that are loaded here were
%made with the text2im_generate_glyphs_from_font function, which has many requirements before it
%works properly. For that reason the png files were also put on the Wayback Machine.

if nargin==1
    IM=text2im__download_IM(S.url);
else
    IM=[];
end
if isempty(IM),IM=text2im__get_IM_from_user(S);end

%Read row1.
sz=bin2dec(char('0'+reshape(IM(1,1:60),20,3)'));

%Split into glyphs.
dim1=(sz(1))*ones(1,ceil(sz(3)/32));
dim2=(sz(2)+1)*ones(1,32);% +1 to account for the codepoint encoding
c=mat2cell(IM(2:end,:),dim1,dim2);
c=c';c=c(1:sz(3));

glyphs=cell(size(c));
printable=zeros(size(c));
r_=max(1,sz(1)-17);%At most 16 bits are used for the codepoint.
for k=1:numel(c)
    glyphs{k}=c{k}(:,2:end);
    printable(k)=bin2dec(char('0'+c{k}(r_:end,1)'));
end
end
function IM=text2im__download_IM(url)
for tries=1:3
    try
        IM=imread(url);
        break
    catch
        IM=[];
    end
end
if isempty(IM)
    %As a fallback for when there is something wrong with the Wayback Machine, we can still try
    %loading from hjwisselink.nl directly instead.
    % remove 'http://web.archive.org/web/yyyymmddhhmmssim_/'
    %        0         1         2         3         4    4
    %        0123456789012345678901234567890123456789012345
    tmp=url(46:end);
    try
        IM=imread(tmp);
    catch
        IM=[];
    end
end
end
function IM=text2im__get_IM_from_user(S)
%Create a GUI to let the user download and select the file.
explanation={'Loading of image failed.','',['You can try again or manually download the image ',...
    'from the URL below.'],'',['Once you have downloaded the png, click the button and locate ',...
    'the file.']};
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
    'Callback',@text2im__select_png);
h=struct('f',f);guidata(f,h)
uiwait(f)
h=guidata(f);
close(f)
IM=imread(fullfile(h.path,h.file));
end
function text2im__select_png(obj,e) %#ok<INUSD>
h=guidata(obj);
[h.file,h.path]=uigetfile('text2im_glyphs_*.png');
guidata(obj,h);
uiresume(h.f);
end
function [HasGlyph,glyphs,valid]=text2im_load_database(fontname,varargin)
%The list of included characters is based on a mostly arbitrary selection from the pages below.

%types:
% 1: printable (subset of the 'normal' characters with well-defined glyphs)
% 2: blank (spaces and tabs)
% 3: newline (line feed, carriage return, etc)
% 4: zero width (soft hyphen and joining characters)

% An attempt was made to include all of these codepoints:
% printable=sort([33:126 161:172 174:328 330:383 913:929 931:1023 8211:8213 8215:8222 8224:8226 ...
%     8230 8240 8227 8243 8249 8250 8252 8254 8260 8266 8352:8383 8448:8527 8592:8703]);
% This selection is based on these pages:
%https://en.wikipedia.org/wiki/List_of_Unicode_characters
%https://en.wikipedia.org/wiki/Newline#Unicode
%https://en.wikipedia.org/wiki/Whitespace_character#Unicode
persistent glyph_database
if nargin<2,purge=false;else,purge=varargin{1};end
if nargin<3,triggerGUI=false;else,triggerGUI=true;end
if purge,glyph_database=[];end
if isempty(glyph_database)
    matfilename=fullfile(GetWritableFolder,'FileExchange','text2im','glyph_database.mat');
    f=fileparts(matfilename);if ~exist(f,'dir'),mkdir(f);end
    if exist(matfilename,'file'),S=load(matfilename);fn=fieldnames(S);glyph_database=S.(fn{1});end
    if purge,glyph_database=[];end
    if isempty(glyph_database)
        if triggerGUI
            glyph_database=text2im_create_pref_struct(triggerGUI);
        else
            glyph_database=text2im_create_pref_struct;
        end
        save(matfilename,var2str(glyph_database),get_MatFileFlag)
    end
end

if nargin>0
    name_list={glyph_database.valid_name};
    idx=find(ismember(name_list,fontname));
    if isempty(idx)
        warning('HJW:text2im:IncorrectFontName',...
            'Font name doesn''t match any implemented font, reverting to default.')
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
function str=tmpname(StartFilenameWith,ext)
%Inject a string in the file name part returned by the tempname function.
if nargin<1,StartFilenameWith='';end
if ~isempty(StartFilenameWith),StartFilenameWith=[StartFilenameWith '_'];end
if nargin<2,ext='';else,if ~strcmp(ext(1),'.'),ext=['.' ext];end,end
str=tempname;
[p,f]=fileparts(str);
str=fullfile(p,[StartFilenameWith f ext]);
end
function unicode=UTF16_to_unicode(UTF16)
%Convert UTF-16 to the code points stored as uint32
%
%See https://en.wikipedia.org/wiki/UTF-16
%
% 1 word (U+0000 to U+D7FF and U+E000 to U+FFFF):
%  xxxxxxxx_xxxxxxxx
% 2 words (U+10000 to U+10FFFF):
%  110110xx_xxxxxxxx 110111xx_xxxxxxxx

persistent isOctave,if isempty(isOctave),isOctave = exist('OCTAVE_VERSION', 'builtin') ~= 0;end
UTF16=uint32(UTF16);

multiword= UTF16>55295 & UTF16<57344; %0xD7FF and 0xE000
if ~any(multiword)
    unicode=UTF16;return
end

word1= find( UTF16>=55296 & UTF16<=56319 );
word2= find( UTF16>=56320 & UTF16<=57343 );
try
    d=word2-word1;
    if any(d~=1)
        error('trigger error')
    end
catch
    error('input is not valid UTF-16 encoded')
end

%Binary header:
% 110110xx_xxxxxxxx 110111xx_xxxxxxxx
% 00000000 01111111 11122222 22222333
% 12345678 90123456 78901234 56789012
header_bits='110110110111';header_locs=[1:6 17:22];
multiword=UTF16([word1.' word2.']);
multiword=unique(multiword,'rows');
S2=mat2cell(multiword,ones(size(multiword,1),1),2);
unicode=UTF16;
for n=1:numel(S2)
    bin=dec2bin(double(S2{n}))';
    
    if ~strcmp(header_bits,bin(header_locs))
        error('input is not valid UTF-16 encoded')
    end
    bin(header_locs)='';
    if ~isOctave
        S3=uint32(bin2dec(bin  ));
    else
        S3=uint32(bin2dec(bin.'));%Octave needs an extra transpose.
    end
    S3=S3+65536;% 0x10000
    %Perform actual replacement.
    unicode=PatternReplace(unicode,S2{n},S3);
end
end
function [unicode,isUTF8,assumed_UTF8]=UTF8_to_unicode(UTF8,print_to)
%Convert UTF-8 to the code points stored as uint32
%Plane 16 goes up to 10FFFF, so anything larger than uint16 will be able to hold every code point.
%
%If there a second output argument, this function will not return an error if there are encoding
%error. The second output will contain the attempted conversion, while the first output will
%contain the original input converted to uint32.
%
%The second input can be used to also print the error to a GUI element or to a text file.
if nargin<2,print_to=[];end
return_on_error= nargout==1 ;

UTF8=uint32(UTF8);
[assumed_UTF8,flag,ME]=UTF8_to_unicode_internal(UTF8,return_on_error);
if strcmp(flag,'success')
    isUTF8=true;
    unicode=assumed_UTF8;
elseif strcmp(flag,'error')
    isUTF8=false;
    if return_on_error
        error_(print_to,ME)
    end
    unicode=UTF8;%Return input unchanged (apart from casting to uint32).
end
end
function [UTF8,flag,ME]=UTF8_to_unicode_internal(UTF8,return_on_error)

flag='success';
ME=struct('identifier','HJW:UTF8_to_unicode:notUTF8','message','Input is not UTF-8.');

persistent isOctave,if isempty(isOctave),isOctave = exist('OCTAVE_VERSION', 'builtin') ~= 0;end

if any(UTF8>255)
    flag='error';
    if return_on_error,return,end
elseif all(UTF8<128)
    return
end

for bytes=4:-1:2
    val=bin2dec([repmat('1',1,bytes) repmat('0',1,8-bytes)]);
    multibyte=UTF8>=val & UTF8<256;%Exclude the already converted chars.
    if any(multibyte)
        multibyte=find(multibyte);multibyte=multibyte(:).';
        if numel(UTF8)<(max(multibyte)+bytes-1)
            flag='error';
            if return_on_error,return,end
            multibyte( (multibyte+bytes-1)>numel(UTF8) )=[];
        end
        if ~isempty(multibyte)
            idx=bsxfun_plus(multibyte , (0:(bytes-1)).' );
            idx=idx.';
            multibyte=UTF8(idx);
        end
    else
        multibyte=[];
    end
    header_bits=[repmat('1',1,bytes-1) repmat('10',1,bytes)];
    header_locs=unique([1:(bytes+1) 1:8:(8*bytes) 2:8:(8*bytes)]);
    if numel(multibyte)>0
        multibyte=unique(multibyte,'rows');
        S2=mat2cell(multibyte,ones(size(multibyte,1),1),bytes);
        for n=1:numel(S2)
            bin=dec2bin(double(S2{n}))';
            %To view the binary data, you can use this: bin=bin(:)';
            %Remove binary header (3 byte example):
            %1110xxxx10xxxxxx10xxxxxx
            %    xxxx  xxxxxx  xxxxxx
            if ~strcmp(header_bits,bin(header_locs))
                %Check if the byte headers match the UTF-8 standard.
                flag='error';
                if return_on_error,return,end
                continue %leave unencoded
            end
            bin(header_locs)='';
            if ~isOctave
                S3=uint32(bin2dec(bin  ));
            else
                S3=uint32(bin2dec(bin.'));%Octave needs an extra transpose.
            end
            %Perform actual replacement.
            UTF8=PatternReplace(UTF8,S2{n},S3);
        end
    end
end
end
function varargout=var2str(varargin)
%Analogous to func2str, return the variable names as char arrays, as detected by inputname.
%This returns an error for invalid inputs and if nargin~=max(1,nargout).
%
%You can use comma separated lists to create a cell array:
% out=cell(1,2);
% foo=1;bar=2;
% [out{:}]=var2str(foo,bar);
err_flag= nargin~=max(1,nargout) ;
if ~err_flag
    varargout=cell(nargin,1);
    for n=1:nargin
        try varargout{n}=inputname(n);catch,varargout{n}='';end
        if isempty(varargout{n}),err_flag=true;break,end
    end
end
if err_flag
    error('Invalid input and/or output.')
end
end