% 16-COLOR BMP IMAGE TO ASCII TXT FILE
I = imread('random.bmp');
dlmwrite('random.txt', I, 'delimiter', ' ');