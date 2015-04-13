//
//  DemodulationUtils.mm
//  Enlighten
//
//  Created by Darrin Willis on 3/30/15.
//  Copyright (c) 2015 18-549 Team10. All rights reserved.
//

#import "DemodulationUtils.h"

@implementation DemodulationUtils

+ (cv::Mat)getHann:(int)n
{
    cv::Mat window = cv::Mat();
    for (int i = 0; i < n; i++)
    {
        double multiplier = 0.5 * (1 - cos(2 * M_PI / (n - 1)));
        window.push_back(multiplier);
    }
    return window;
}

+ (cv::Mat)getFFT:(cv::Mat)imageRows withFreq:(cv::Mat)frequencies
{
    NSLog(@"The given image is of size %i by %i", imageRows.rows, imageRows.cols);
    // This should be the same size as a single image height
    int Nfft = 1080;
    // This is how far apart our samples are for each sample
    int stepsPerFrame = 10;
    int stepSize = Nfft / stepsPerFrame;
    //int numFrames = imageRows.rows / Nfft;
    
    // The number of frequencies we are scanning for
    int numFreqs = frequencies.cols;
    
    //int endVal = (numFrames - 1) * imageRows.rows;
    int numWindows = imageRows.rows / stepSize;
    cv::Mat computedFft = cv::Mat(numWindows, frequencies.cols, 0);
    
    int h = 0;
    for (int i = 0; i < imageRows.rows - Nfft; i+= stepSize) {
        //First get a Mat representing this image
        NSLog(@"FFTing on window from %i to %i", i, i+Nfft);
        cv::Mat thisImage = imageRows.rowRange(i, i + Nfft);
        
        int pixel_new = i % Nfft;
        int pixel_old = Nfft - pixel_new;
        cv::Mat hann = [DemodulationUtils getHann:pixel_old];
        hann.push_back([DemodulationUtils getHann:pixel_new]);
        NSLog(@"Have hann filter of size %i by %i", hann.size().height, hann.size().width);
        NSLog(@"Have matrix size %i by %i", thisImage.size().height, thisImage.size().width);
        
        thisImage = thisImage.t().mul(hann.t()).t();
        
        // This is copied from OpenCV documentation on how to use DFT
        cv::Mat padded;                            //expand input image to optimal size
        int m = cv::getOptimalDFTSize( thisImage.rows );
        int n = cv::getOptimalDFTSize( thisImage.cols ); // on the border add zero values
        cv::copyMakeBorder(thisImage, padded, 0, m - thisImage.rows, 0, n - thisImage.cols, cv::BORDER_CONSTANT, cv::Scalar::all(0));
        
        cv::Mat planes[] = {cv::Mat_<double>(padded), cv::Mat::zeros(padded.size(), CV_64F)};
        cv::Mat complexI;
        cv::merge(planes, 2, complexI);
        
        cv::dft(complexI, complexI);
        cv::split(complexI, planes);
        cv::magnitude(planes[0], planes[1], planes[0]);
        cv::Mat thisFft = planes[0];
        
        NSLog(@"Size of thisFFt = %i x %i", thisFft.rows, thisFft.cols);
        
        // Iterate through the target frequencies
        for (int j = 0; j < numFreqs; j++) {
            double freq = frequencies.at<double>(0, j);
            cv::Mat releventFreqs = thisFft.rowRange(freq - 2, freq + 2);
            cv::Mat squared = releventFreqs.mul(releventFreqs);
            double val = sqrt(sum(squared)[0] / 5);
            if (isnan(val)) val = 0;
            computedFft.at<double>(h, j) = abs(val);
        }
        h++;
    }
    return computedFft;
}


@end