clear
clc

%broj bita odbirka (format je 1.23)
word_length = 24;
fraction_length = 23;
fs = 22050;
f1 = 400;
f2 = 4000;

%specifikacija NF filtra
fir_ord = 20;
Wn=0.1;
%odbirci prozorske funkcije koja se koristi
pravougaoni = rectwin(fir_ord+1);
%projektovanje FIR filtara koriscenjem funkcije fir1
b = fir1 (fir_ord, Wn, pravougaoni);
a = 1;
%diskretno vreme
n = 0:149;
%definisanje ulaznog signala u trajanju od 150 odbiraka
u = 0.7*cos(2*pi*f1/fs*n) + 0.15*cos(2*pi*f2/fs*n);

struct.mode = 'fixed';
struct.roundmode = 'floor';
struct.overflowmode = 'saturate';
struct.format = [word_length fraction_length];
q = quantizer(struct);

%digitalizacija diskretnog signala
u_digital = quantize(q,u);

%filtriranje signala pomocu formiranog filtra
y_real = filter(b,a,u_digital);
y_digital = quantize(q, y_real);

%crtanje ulaznog i izlaznog signala
set(gcf, 'color', 'w');
subplot(2,1,1), stem(n,u), title('Ulazni signal u trajanju od 150 odbiraka');
subplot(2,1,2), stem(n,y_digital), title('Izlazni signal u trajanju od 150 odbiraka racunat pomocu funkcije filter');

%koeficijenti filtra
fileIDb = fopen('coef.txt','w');
for i=1:fir_ord+1
    fprintf(fileIDb,num2bin(q,b(i)));
    fprintf(fileIDb,'\n');
end
fclose(fileIDb);

% Ispis ulaznih vektora u datoteku
fileIDb = fopen('input.txt','w');
for i=1:length(u_digital)
    fprintf(fileIDb,num2bin(q,u_digital(i)));
    fprintf(fileIDb,'\n');
end
fclose(fileIDb);

% Ispis očekivanih izlaznih vektora u datoteku
fileIDb = fopen('expected.txt','w');
for i=1:length(y_digital)
    fprintf(fileIDb,num2bin(q,y_digital(i)));
    fprintf(fileIDb,'\n');
end
fclose(fileIDb);