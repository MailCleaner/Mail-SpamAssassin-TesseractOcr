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
new(class)
        SV *class;
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
xs_createImage(self,width,height,IPL_DEPTH,Channel)
        SV *self;
        int width;
        int height;
        int IPL_DEPTH;
        int Channel;
    PREINIT:
        IplImage *img;
    CODE:
        RETVAL = cvCreateImage(cvSize(width,height),IPL_DEPTH,Channel);
    OUTPUT:
        RETVAL

IplImage *
xs_loadImage(self,filename)
        SV *self;
        char *filename;
    PREINIT:
        IplImage *img;
    CODE:
        RETVAL = cvLoadImage (filename, CV_LOAD_IMAGE_ANYDEPTH | CV_LOAD_IMAGE_ANYCOLOR);
    OUTPUT:
        RETVAL

SV *
xs_saveImage(self,filename,image)
        SV *self;
        char *filename;
        SV *image;
    PREINIT:
        IplImage *img;
        int i;
    CODE:
        img = INT2PTR(IplImage *, SvIV(SvRV(image)));
        i = cvSaveImage(filename, img, 0);
        RETVAL = newSVuv(i);
    OUTPUT:
        RETVAL

void
xs_releaseImage(self,image)
        SV *self;
        SV *image;
    PREINIT:
        IplImage *img;
    CODE:
        img = INT2PTR(IplImage *, SvIV(SvRV(image)));
        cvReleaseImage(&img);

SV *
xs_getWidth(self,image)
        SV *self;
        SV *image;
    PREINIT:
        IplImage *input;
    CODE:
        input = INT2PTR(IplImage *, SvIV(SvRV(image)));
        RETVAL = newSVuv(input->width);
    OUTPUT:
        RETVAL

SV *
xs_getHeight(self,image)
        SV *self;
        SV *image;
    PREINIT:
        IplImage *input;
    CODE:
        input = INT2PTR(IplImage *, SvIV(SvRV(image)));
        RETVAL = newSVuv(input->height);
    OUTPUT:
        RETVAL

SV *
xs_getDepth(self,image)
        SV *self;
        SV *image;
    PREINIT:
        IplImage *input;
    CODE:
        input = INT2PTR(IplImage *, SvIV(SvRV(image)));
        RETVAL = newSVuv(input->depth);
    OUTPUT:
        RETVAL

SV *
xs_getChannels(self,image)
        SV *self;
        SV *image;
    PREINIT:
        IplImage *input;
    CODE:
        input = INT2PTR(IplImage *, SvIV(SvRV(image)));
        RETVAL = newSVuv(input->nChannels);
    OUTPUT:
        RETVAL

SV *
xs_addBorder(self,image)
        SV *self;
        SV *image;
    PREINIT:
        IplImage *before;
        IplImage *after;
        CvPoint offset;
        int type;
        CvScalar color;
    CODE:
        before = INT2PTR(IplImage *, SvIV(SvRV(image)));
        after = cvCreateImage(cvSize(before->width+100,before->height+100),before->depth,3);
        type = 0;
        color = cvScalarAll(255);
        offset.x = offset.y = 50;
        cvCopyMakeBorder(before,after,offset,type,color);
        image = newSViv(PTR2IV(after));
        image = newRV_noinc(image);
        RETVAL = image;
    OUTPUT:
        RETVAL

int
xs_split(self,image,red,green,blue,alpha)
        SV *self;
        IplImage *image;
        IplImage *red;
        IplImage *green;
        IplImage *blue;
        IplImage *alpha;
    CODE:
        printf("%d\n",image->nChannels);
        cvSplit(image,red,green,blue,NULL);

SV *
xs_blur(self,image,x,y);
        SV *self;
        SV *image;
        int x;
        int y;
    PREINIT:
        IplImage *before;
        IplImage *after;
        int method;
        double sigma1;
        double sigma2;
    CODE:
        method = 1; // CV_BLUR
        sigma1 = 0;
        sigma2 = 0;
        before = INT2PTR(IplImage *, SvIV(SvRV(image)));
        after = cvCreateImage(cvSize(before->width,before->height),before->depth,before->nChannels);
        cvSmooth ( before, after, method, x, y, sigma1, sigma2 );
        image = newSViv(PTR2IV(after));
        image = newRV_noinc(image);
        RETVAL = image;
    OUTPUT:
        RETVAL

SV *
xs_convertToGray(self,image)
        SV *self;
        SV *image;
    PREINIT:
        IplImage *before;
        IplImage *after;
    CODE:
        before = INT2PTR(IplImage *, SvIV(SvRV(image)));
        after = cvCreateImage(cvSize(before->width,before->height),before->depth,1);
        if(before->nChannels == 1 ){
            cvCopy(before,after,NULL);
        }else{
            cvCvtColor ( before, after, CV_BGR2GRAY);
        }
        image = newSViv(PTR2IV(after));
        image = newRV_noinc(image);
        RETVAL = image;
    OUTPUT:
        RETVAL

