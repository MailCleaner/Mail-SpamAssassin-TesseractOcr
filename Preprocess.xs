#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>
#define NEED_newRV_noinc
#define NEED_sv_2pv_nolen
#include <cv.h>
#include <highgui.h>
#include <ctype.h>
#include <stdio.h>
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

SV *
xs_createImage(self,width,height,IPL_DEPTH,Channel)
        SV *self;
        int width;
        int height;
        int IPL_DEPTH;
        int Channel;
    PREINIT:
        IplImage *img;
        SV *image;
    CODE:
        img = cvCreateImage(cvSize(width,height),IPL_DEPTH,Channel);
        image = newSViv(PTR2IV(img));
        image = newRV_noinc(image);
        RETVAL = image;
    OUTPUT:
        RETVAL

SV *
xs_loadImage(self,filename)
        SV *self;
        char *filename;
    PREINIT:
        IplImage *img;
        SV *image;
    CODE:
        img = cvLoadImage (filename, CV_LOAD_IMAGE_ANYDEPTH | CV_LOAD_IMAGE_ANYCOLOR);
        if(img){
            image = newSViv(PTR2IV(img));
            image = newRV_noinc(image);
            RETVAL = image;
        }else{
            RETVAL = newSVuv(0);
        }
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
        SV *outImage;
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

SV *
xs_split(self,image,channels)
        SV *self;
        SV *image;
        SV *channels;
    PREINIT:
        IplImage *img,*red_chan,*green_chan,*blue_chan,*alpha_chan;
        AV *ret;
        SV *red,*green,*blue,*alpha;
    CODE:
        img = INT2PTR(IplImage *, SvIV(SvRV(image)));
        if ( img->nChannels == 1 ){
            av_push (ret, image);
        } else {
            red_chan = cvCreateImage(cvSize(img->width,img->height),img->depth,1);
            green_chan = cvCreateImage(cvSize(img->width,img->height),img->depth,1);
            blue_chan = cvCreateImage(cvSize(img->width,img->height),img->depth,1);
            alpha_chan = cvCreateImage(cvSize(img->width,img->height),img->depth,1);
            cvSplit(img,red_chan,green_chan,blue_chan,alpha_chan);
            red = newSViv(PTR2IV(red_chan));
            red = newRV_noinc(red);
            av_push (ret, red);
            green = newSViv(PTR2IV(green_chan));
            green = newRV_noinc(green);
            av_push (ret, green);
            blue = newSViv(PTR2IV(blue_chan));
            blue = newRV_noinc(blue);
            av_push (ret, blue);
            if (img->nChannels == 4) {
                alpha = newSViv(PTR2IV(alpha_chan));
                alpha = newRV_noinc(alpha);
                av_push (ret, alpha);
            }
        }
        RETVAL = newRV((SV *)ret);
    OUTPUT:
        RETVAL

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

