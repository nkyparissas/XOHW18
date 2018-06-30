% 256-COLOR BMP IMAGE TO ASCII TXT FILE
% This script transforms an 8-bit indexed BMP image to greyscale ASCII TXT

clear all;

[I, RGBMAP] = imread('random.bmp');

newmap = rgb2gray(RGBMAP);

%write palette
for i = 1:1080
    for j = 1:1920        
		new_image(i,j) = newmap(I(i,j)+1,1);        
	end
end

new_image = new_image * 255;
new_image = round(new_image);

dlmwrite('random.txt', new_image, 'delimiter', ' ');
imwrite(I, newmap,'random_8b_intensity.bmp')