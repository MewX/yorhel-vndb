package VNWeb::Misc::ImageUpload;

use VNWeb::Prelude;
use Image::Magick;

sub save_img {
    my($im, $id, $thumb, $ow, $oh, $pw, $ph) = @_;

    if($pw) {
        my($nw, $nh) = imgsize($ow, $oh, $pw, $ph);
        if($ow != $nw || $oh != $nh) {
            $im->GaussianBlur(geometry => '0.5x0.5');
            $im->Resize(width => $nw, height => $nh);
            $im->UnsharpMask(radius => 0, sigma => 0.75, amount => 0.75, threshold => 0.008);
        }
    }

    my $fn = tuwf->imgpath($id, $thumb);
    $im->Write($fn) && die "Error saving $fn: $!\n";
    chmod 0666, $fn;
}


TUWF::post qr{/elm/ImageUpload.json}, sub {
    if(!auth->csrfcheck(tuwf->reqHeader('X-CSRF-Token')||'')) {
        warn "Invalid CSRF token in request\n";
        return elm_CSRF;
    }
    return elm_Unauth if !auth->permEdit;

    my $type = tuwf->validate(post => type => { enum => [qw/cv ch sf/] })->data;
    my $imgdata = tuwf->reqUploadRaw('img');
    return elm_ImgFormat if $imgdata !~ /^(\xff\xd8|\x89\x50)/; # JPG or PNG header

    my $im = Image::Magick->new;
    $im->BlobToImage($imgdata);
    $im->Set(magick => 'JPEG');
    $im->Set(background => '#ffffff');
    $im->Set(alpha => 'Remove');
    $im->Set(quality => 90);

    my($ow, $oh) = ($im->Get('width'), $im->Get('height'));
    my($nw, $nh) =
        $type eq 'ch' ? imgsize $ow, $oh, tuwf->{ch_size}->@* :
        $type eq 'cv' ? imgsize $ow, $oh, tuwf->{cv_size}->@* : ($ow, $oh);

    my $seq = {qw/sf screenshots_seq cv covers_seq ch charimg_seq/}->{$type}||die;
    my $id = tuwf->dbVali('INSERT INTO images', {
        id     => sql_func(vndbid => \$type, sql(sql_func(nextval => \$seq), '::int')),
        width  => $nw,
        height => $nh
    }, 'RETURNING id');

    save_img $im, $id, 0, $ow, $oh, $nw, $nh;
    save_img $im, $id, 1, $nw, $nh, tuwf->{scr_size}->@* if $type eq 'sf';

    elm_Image $id, $ow, $oh;
};

1;
