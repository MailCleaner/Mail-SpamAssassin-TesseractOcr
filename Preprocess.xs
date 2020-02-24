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
        image = cvCreateImage(size, depth, channels);
        cvZero(image);
        RETVAL = image;
    OUTPUT:
        RETVAL

IplImage *
cvLoadImage(char *filename, int iscolor=CV_LOAD_IMAGE_COLOR)

void
cvSaveImage(char *filename, IplImage *image, const int *params)

void
cvRelease(IplImage *image)
    PREINIT:
        IplImage **imgref;
    CODE:
        imgref = &image;
        cvReleaseImage(imgref);

void
cvReleaseImage(IplImage **image)

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
cvCvtColor (IplImage *image, IplImage *output, int code)

void
cvZero(IplImage *image)

void
cvCopy(IplImage *in, IplImage *out, NULL)

IplImage *
cvToColor(IplImage *image)
    PREINIT:
        IplImage *output;
    CODE:
        if ( image->nChannels >= 3 ) {
            RETVAL = image;
        } else {
            output = cvCreateImage(cvSize(image->width,image->height),image->depth,3);
            cvCvtColor ( image, output, CV_GRAY2BGR);
            RETVAL = output;
        }
    OUTPUT:
        RETVAL

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
cvCanny(const IplImage *before, IplImage *after, double min, double max, int kernel = 3)
    POSTCALL:
        ST(0) = ST(1);
        XSRETURN(1);

void
cvAdd(IplImage *img1, IplImage *img2, IplImage *dst, NULL)

void
cvNot(IplImage *before, IplImage *after)

IplImage *
cvInvert(IplImage *image)
    CODE:
        cvNot(image,image);
        RETVAL = image;
    OUTPUT:
        RETVAL

IplImage *
cvContours(IplImage *edges)
    PREINIT:
        IplImage *output;
        CvMemStorage *mem;
        CvSeq *contours;
        CvScalar color;
        int n;
    CODE:
        output = cvCreateImage(cvSize(edges->width,edges->height),edges->depth,1);
        cvZero(output);
        mem = cvCreateMemStorage(0);
        contours = 0;
        //n = cvFindContours(edges, mem, &contours, sizeof(CvContour), CV_RETR_TREE, CV_CHAIN_APPROX_SIMPLE, cvPoint(0,0));
        //n = cvFindContours(edges, mem, &contours, sizeof(CvContour), CV_RETR_CCOMP, CV_CHAIN_APPROX_NONE, cvPoint(0,0));
        // Or this:
        n = cvFindContours(edges, mem, &contours, sizeof(CvContour), CV_RETR_LIST, CV_CHAIN_APPROX_SIMPLE, cvPoint(0,0));
        int i = 1;
        /*
        for (; i <= sizeof(n); i++) {
        */
        for (; contours != 0; contours = contours->h_next) {
            color = cvScalarAll(255);
            CvRect rect = cvBoundingRect(contours,1);
            double w = rect.width * 1.0;
            double h = rect.height * 1.0;
            int count = 0;
            if ((w * h) <= ((output->width * output->height)/5) && (w / h) >= 0.1 && (w / h) <= 10) {
                cvDrawContours(output, contours, color, CV_RGB(0,0,0), -1, CV_FILLED, 8, cvPoint(0,0));
            }
            i++;
        }
        RETVAL = output;
    OUTPUT:
        RETVAL

void
cvThreshold(IplImage *input, IplImage *output, double threshold, double max, int threshold_type)

void
cvAdaptiveThreshold(IplImage *input, IplImage *output, double max, int adaptive_method, int threshold_type, int adaptive_size, double param1)

IplImage *
cvMask(IplImage *image, IplImage *mask)
    PREINIT:
        IplImage *output;
    CODE:
        output = cvCreateImage(cvSize(image->width,image->height),image->depth,image->nChannels);
        cvAnd(image,mask,output,NULL);
        RETVAL = output;
    OUTPUT:
        RETVAL

int
cvFindContours(IplImage *image, CvMemStorage* storage, OUT CvSeq* first_contour, int header_size=sizeof(CvContour), int mode=CV_RETR_LIST, int method=CV_CHAIN_APPROX_SIMPLE, CvPoint offset=cvPoint(0, 0))
