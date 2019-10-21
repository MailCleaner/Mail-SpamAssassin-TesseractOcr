#ifndef __Inline_C

#ifdef __cplusplus
extern "C" {
#endif
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>
#ifdef __cplusplus
}
#endif

/*
#define NEED_newRV_noinc
#define NEED_sv_2pv_nolen
*/
#define NEED_sv_2pv_nolen_GLOBAL
#include "./ppport.h"

#endif /* __Inline_C */

#undef do_open
#undef do_close
#undef seed

#include <ctype.h>
#include <stdio.h>
#include <opencv/cv.h>
#include <opencv/highgui.h>
#include <opencv2/imgcodecs/imgcodecs_c.h>
#include <opencv2/imgproc/imgproc_c.h>

MODULE = Mail::SpamAssassin::Plugin::TesseractOcr::Preprocess   PACKAGE = Mail::SpamAssassin::Plugin::TesseractOcr::Preprocess

PROTOTYPES: ENABLE

SV *
new(SV *class)
    PREINIT:
        SV *self;
    CODE:
        self = newSViv(1);
        self = newRV_noinc(self);
        sv_bless(self, gv_stashpv(SvPV_nolen(class), 1));
        RETVAL = self;
    OUTPUT:
        RETVAL

IplImage *
cvCreateImage(int height, int width, int depth, int channels)
    PREINIT:
        IplImage *image;
        CvSize size;
    CODE:
        size = cvSize(height,width);
        RETVAL = cvCreateImage(size, depth, channels);
    OUTPUT:
        RETVAL

IplImage *
cvLoadImage(char *filename, int iscolor=CV_LOAD_IMAGE_COLOR)

void
cvSaveImage(char *filename, IplImage *image, const int *params)

int
cvGetWidth(IplImage *image)
    CODE:
        RETVAL = image->width;
    OUTPUT:
        RETVAL

int
cvGetHeight(IplImage *image)
    CODE:
        RETVAL = image->height;
    OUTPUT:
        RETVAL

int
cvGetDepth(IplImage *image)
    CODE:
        RETVAL = image->depth;
    OUTPUT:
        RETVAL

int
cvGetChannels(IplImage *image)
    CODE:
        RETVAL = image->nChannels;
    OUTPUT:
        RETVAL

IplImage *
cvAddBorder(IplImage *image)
    PREINIT:
        IplImage *output;
        CvPoint offset;
        CvScalar color;
    CODE:
        output = cvCreateImage(cvSize(image->width+100,image->height+100),image->depth,image->nChannels);
        color = cvScalarAll(255);
        offset.x = offset.y = 50;
        cvCopyMakeBorder(image,output,offset,0,color);
        RETVAL = output;
    OUTPUT:
        RETVAL

void
cvSplit(IplImage *image,IplImage *red,IplImage *green,IplImage *blue, NULL)

IplImage *
cvBlur(IplImage *image,int x,int y);
    PREINIT:
        IplImage *output;
        int method;
        double sigma1;
        double sigma2;
    CODE:
        method = 1; // CV_BLUR
        sigma1 = 0;
        sigma2 = 0;
        output = cvCreateImage(cvSize(image->width,image->height),image->depth,image->nChannels);
        cvSmooth ( image, output, method, x, y, sigma1, sigma2 );
        RETVAL = output;
    OUTPUT:
        RETVAL

void
cvCvtColor (IplImage *image, IplImage *output, CV_BGR2GRAY)

IplImage *
cvToGray(IplImage *image)
    PREINIT:
        IplImage *output;
    CODE:
        if ( image->nChannels == 1 ) {
            RETVAL = image;
        } else {
            output = cvCreateImage(cvSize(image->width,image->height),image->depth,1);
            cvCvtColor ( image, output, CV_BGR2GRAY);
            RETVAL = output;
        }
    OUTPUT:
        RETVAL

void
cvZero(IplImage *image)

void
cvCopy(IplImage *in, IplImage *out, NULL)

void
cvCanny(const IplImage *before, IplImage *after, double min, double max, int kernel = 3)
    POSTCALL:
        ST(0) = ST(1);
        XSRETURN(1);

IplImage *
old_cvEdges (IplImage *image)
    PREINIT:
        IplImage *output;
    CODE:
        output = cvCreateImage(cvSize(image->width,image->height),image->depth,image->nChannels);
        cvZero(output);
        cvCanny(image,output,50,200,3);
        RETVAL = output;
    OUTPUT:
        RETVAL

