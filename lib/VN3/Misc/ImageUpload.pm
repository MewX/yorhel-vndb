package VN3::Misc::ImageUpload;

use strict;
use warnings;
use Image::Magick;
use TUWF;
use VNDBUtil;
use VN3::Auth;


sub save_img {
    my($im, $dir, $id, $ow, $oh, $pw, $ph) = @_;

    if($pw) {
        my($nw, $nh) = imgsize($ow, $oh, $pw, $ph);
        if($ow != $nw || $oh != $nh) {
            $im->GaussianBlur(geometry => '0.5x0.5');
            $im->Resize(width => $nw, height => $nh);
            $im->UnsharpMask(radius => 0, sigma => 0.75, amount => 0.75, threshold => 0.008);
        }
    }

    my $fn = tuwf->imgpath($dir, $id);
    $im->Write($fn);
    chmod 0666, $fn;
}


TUWF::post '/js/imageupload.json', sub {
    if(!auth->csrfcheck(tuwf->reqHeader('X-CSRF-Token')||'')) {
        warn "Invalid CSRF token in request";
        tuwf->resJSON({CSRF => 1});
        return;
    }
    return tuwf->resJSON({Unauth => 1}) if !auth->permEdit;

    my $type = tuwf->validate(post => type => { enum => [qw/cv ch sf/] })->data;
    my $imgdata = tuwf->reqUploadRaw('img');
    return tuwf->resJSON({ImgFormat => 1}) if $imgdata !~ /^(\xff\xd8|\x89\x50)/; # JPG or PNG header

    my $im = Image::Magick->new;
    $im->BlobToImage($imgdata);
    $im->Set(magick => 'JPEG');
    $im->Set(background => '#ffffff');
    $im->Set(alpha => 'Remove');
    $im->Set(quality => 90);
    my($ow, $oh) = ($im->Get('width'), $im->Get('height'));
    my $id;


    # VN cover image
    if($type eq 'cv') {
        $id = tuwf->dbVali("SELECT nextval('covers_seq')");
        save_img $im, cv => $id, $ow, $oh, 256, 400;

    # Screenshot
    } elsif($type eq 'sf') {
        $id = tuwf->dbVali('INSERT INTO screenshots', { width => $ow, height => $oh }, 'RETURNING id');
        save_img $im, sf => $id;
        save_img $im, st => $id, $ow, $oh, 136, 102;

    # Character image
    } elsif($type eq 'ch') {
        $id = tuwf->dbVali("SELECT nextval('charimg_seq')");
        save_img $im, ch => $id, $ow, $oh, 256, 300;
    }


    tuwf->resJSON({Image => [$id, $ow, $oh]});
};


1;
