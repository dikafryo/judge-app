<?php

declare(strict_types=1);

/**
 * 기기에서 찍은 스크린샷을 플레이 규격에 맞춘다.
 *
 *   php tools/fix-screenshots.php
 *
 * 왜 필요한가 — 플레이는 "긴 변이 짧은 변의 2배를 넘을 수 없다"고 못 박는다.
 * 요즘 폰은 20:9 를 넘어가므로(예: 968x2376 = 2.45) 찍은 그대로는 거부된다.
 *
 * 잘라내지 않고 **좌우를 넓혀서** 맞춘다. 화면 내용을 한 줄도 잃지 않기 위해서다.
 * 채우는 색은 각 행의 가장자리 픽셀을 그대로 늘린 것이라 앱 배경이 이어진 것처럼 보인다.
 */

const MAX_RATIO = 2.0;     // 플레이 상한
const TARGET_RATIO = 1.95; // 반올림 때문에 아슬아슬해지지 않도록 여유를 둔다
const JPEG_QUALITY = 92;

/** 각 행의 가장자리 픽셀을 좌우로 늘려 여백을 채운다. */
function extendEdges(\GdImage $src, int $padLeft, int $newWidth): \GdImage
{
    $w = imagesx($src);
    $h = imagesy($src);

    $out = imagecreatetruecolor($newWidth, $h);
    imagecopy($out, $src, $padLeft, 0, 0, 0, $w, $h);

    for ($y = 0; $y < $h; $y++) {
        if ($padLeft > 0) {
            imageline($out, 0, $y, $padLeft - 1, $y, imagecolorat($src, 0, $y));
        }

        $rightStart = $padLeft + $w;

        if ($rightStart < $newWidth) {
            imageline($out, $rightStart, $y, $newWidth - 1, $y, imagecolorat($src, $w - 1, $y));
        }
    }

    return $out;
}

$dir = dirname(__DIR__).'/store';
$files = glob("{$dir}/IMG_*.jpg") ?: [];
sort($files);

if ($files === []) {
    fwrite(STDERR, "맞출 스크린샷이 없습니다: {$dir}/IMG_*.jpg\n");
    exit(1);
}

$index = 0;

foreach ($files as $file) {
    $src = @imagecreatefromjpeg($file);

    if ($src === false) {
        fwrite(STDERR, '건너뜀 (읽을 수 없음): '.basename($file)."\n");

        continue;
    }

    $w = imagesx($src);
    $h = imagesy($src);
    $ratio = max($w, $h) / min($w, $h);

    $index++;
    $out = sprintf('%s/screenshot-%d.jpg', $dir, $index);

    if ($ratio <= MAX_RATIO) {
        imagejpeg($src, $out, JPEG_QUALITY);
        printf("%-26s %dx%d 비율 %.2f — 그대로 복사\n", basename($file), $w, $h, $ratio);
        imagedestroy($src);

        continue;
    }

    // 세로로 긴 경우만 다룬다 (가로로 긴 스크린샷은 이 앱에 없다)
    $newWidth = (int) ceil($h / TARGET_RATIO);
    $padLeft = (int) floor(($newWidth - $w) / 2);

    $padded = extendEdges($src, $padLeft, $newWidth);
    imagejpeg($padded, $out, JPEG_QUALITY);

    printf(
        "%-26s %dx%d 비율 %.2f → %dx%d 비율 %.2f\n",
        basename($file), $w, $h, $ratio, $newWidth, $h, $h / $newWidth
    );

    imagedestroy($padded);
    imagedestroy($src);
}

echo "\n{$index}장 생성했습니다. Play Console 에는 screenshot-*.jpg 를 올리세요.\n";
