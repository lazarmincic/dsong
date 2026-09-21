clear
clc

%ubaciti iste vrednosti kao one u HDL-u:
%%%%%%%%%%%%%%%%
FILTER_ORDER = 5; 
IN_WIDTH = 24;
OUT_WIDTH = 32;
%%%%%%%%%%%%%%%%

word_len_in = IN_WIDTH;

word_len_out = OUT_WIDTH;

fs = 22050;
f1 = 400;
f2 = 4000;

%specifikacija NF filtra
Wn=0.1;
%odbirci prozorske funkcije koja se koristi
pravougaoni = rectwin(FILTER_ORDER+1);
%projektovanje FIR filtara koriscenjem funkcije fir1
b = fir1 (FILTER_ORDER, Wn, pravougaoni);
a = 1;
%diskretno vreme
n = 0:999;
%definisanje ulaznog signala u trajanju od 1000 odbiraka
u = 0.7*cos(2*pi*f1/fs*n) + 0.15*cos(2*pi*f2/fs*n);

b_fi = fi(b, 1, word_len_in, word_len_in-1);
u_fi = fi(u, 1, word_len_in, word_len_in-1);
u_fi = u_fi.';

acc_word_length = 2 * word_len_in;
acc_frac_length = 2 * word_len_in - 2;

out_word_length = word_len_out;
out_frac_length = word_len_out - 1;

fir_f = dsp.FIRFilter(...
    'Structure','Direct form transposed', ...
    'NumeratorSource','Property',...
    'Numerator', double(b_fi), ...
    'FullPrecisionOverride', false, ...
    'RoundingMethod', 'Floor', ...
    'OverflowAction', 'Wrap', ...
    'AccumulatorDataType', 'Custom', ...
    'CustomAccumulatorDataType', numerictype(1, acc_word_length, acc_frac_length));

y_fi = fir_f(u_fi);

T_out = numerictype(1, word_len_out, word_len_out-1);
F = fimath('RoundingMethod', 'Floor', 'OverflowAction', 'Wrap');
y_out = fi(y_fi, T_out, F);

%crtanje ulaznog i izlaznog signala nakon kvantizacije
set(gcf, 'color', 'w');
subplot(2,1,1), stem(n,u_fi), title('Ulazni signal');
subplot(2,1,2), stem(n,y_fi), title('Izlazni signal');

%koeficijenti filtra
fileIDb = fopen('coef.txt','w');
for i=1:FILTER_ORDER+1
    fprintf(fileIDb, '%s\n', bin(b_fi(i)));
end
fclose(fileIDb);

% Ispis ulaznih vektora u datoteku
fileIDb = fopen('input.txt','w');
for i=1:length(u_fi)
    fprintf(fileIDb, '%s\n', bin(u_fi(i)));
end
fclose(fileIDb);

% Ispis očekivanih izlaznih vektora u datoteku
fileIDb = fopen('expected.txt','w');
for i=1:length(y_out)
    fprintf(fileIDb, '%s\n', bin(y_out(i)));
end
fclose(fileIDb);