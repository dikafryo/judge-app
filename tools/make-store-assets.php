<?php

declare(strict_types=1);

/**
 * 플레이스토어 등록용 그래픽 생성기 — store/*.png
 *
 *   php tools/make-store-assets.php
 *
 * 런처 아이콘(judge/tools/make-icons.php)과 같은 Toolgrid 마크를 쓰되, 스토어 규격이
 * 달라서 따로 만든다.
 *
 *   · 스토어 아이콘은 **투명을 쓰지 않는다.** 정사각을 꽉 채워야 하고, 플레이가
 *     모서리를 둥글게 깎으므로 마크를 안쪽으로 넣어 잘리지 않게 한다.
 *   · 그래픽 이미지(1024x500)는 목록·추천 영역에 쓰인다. 기기에 따라 가장자리가
 *     잘릴 수 있어 중요한 것은 가운데로 모은다.
 *
 * GD 도형에는 안티에일리어싱이 없어 4배로 그린 뒤 축소한다.
 */

const SUPERSAMPLE = 4;

const COLOR_BG = [0x1F, 0x29, 0x33];     // 로고 배경 (slate-800 계열)
const COLOR_CELL = [0xF5, 0xF3, 0xEF];   // 오프화이트 셀 3개
const COLOR_ACCENT = [0x4F, 0x46, 0xE5]; // indigo-600 — judge 강조 셀
const COLOR_TEXT = [0xF8, 0xFA, 0xFC];
const COLOR_MUTED = [0x94, 0xA3, 0xB8];

/** 로고 CSS 비율(padding .36em / gap .18em / box 1.72em) — 런처 아이콘과 같은 값 */
const PAD_RATIO = 0.36 / 1.72;
const GAP_RATIO = 0.18 / 1.72;
const CORNER_RATIO = 0.18 / 1.72;

const FONT_BOLD = '/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc';
const FONT_REGULAR = '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc';

function allocate(\GdImage $im, array $rgb): int
{
    return imagecolorallocate($im, $rgb[0], $rgb[1], $rgb[2]);
}

/** 모서리가 둥근 사각형을 채운다. */
function filledRoundedRect(\GdImage $im, float $x, float $y, float $w, float $h, float $r, int $color): void
{
    $r = min($r, $w / 2, $h / 2);
    $d = (int) round($r * 2);

    if ($d > 0) {
        imagefilledarc($im, (int) round($x + $r), (int) round($y + $r), $d, $d, 180, 270, $color, IMG_ARC_PIE);
        imagefilledarc($im, (int) round($x + $w - $r), (int) round($y + $r), $d, $d, 270, 360, $color, IMG_ARC_PIE);
        imagefilledarc($im, (int) round($x + $r), (int) round($y + $h - $r), $d, $d, 90, 180, $color, IMG_ARC_PIE);
        imagefilledarc($im, (int) round($x + $w - $r), (int) round($y + $h - $r), $d, $d, 0, 90, $color, IMG_ARC_PIE);
    }

    imagefilledrectangle($im, (int) round($x + $r), (int) round($y), (int) round($x + $w - $r), (int) round($y + $h), $color);
    imagefilledrectangle($im, (int) round($x), (int) round($y + $r), (int) round($x + $w), (int) round($y + $h - $r), $color);
}

/** Toolgrid 마크(2x2 격자, 우하단만 강조색)를 정사각 영역에 그린다. */
function drawMark(\GdImage $im, float $ox, float $oy, float $box, bool $roundedBackground): void
{
    if ($roundedBackground) {
        filledRoundedRect($im, $ox, $oy, $box, $box, $box * CORNER_RATIO, allocate($im, COLOR_BG));
    }

    $pad = $box * PAD_RATIO;
    $gap = $box * GAP_RATIO;
    $cell = ($box - 2 * $pad - $gap) / 2;
    $rad = $cell * 0.12;

    $light = allocate($im, COLOR_CELL);
    $accent = allocate($im, COLOR_ACCENT);

    foreach ([[0, 0], [1, 0], [0, 1], [1, 1]] as $index => [$col, $row]) {
        filledRoundedRect(
            $im,
            $ox + $pad + $col * ($cell + $gap),
            $oy + $pad + $row * ($cell + $gap),
            $cell,
            $cell,
            $rad,
            $index === 3 ? $accent : $light,
        );
    }
}

/** 4배로 그린 캔버스를 목표 크기로 줄여 저장한다. */
function downsampleAndSave(\GdImage $big, int $w, int $h, string $path): void
{
    $out = imagecreatetruecolor($w, $h);
    imagecopyresampled($out, $big, 0, 0, 0, 0, $w, $h, imagesx($big), imagesy($big));
    imagepng($out, $path, 9);
    imagedestroy($out);

    echo sprintf("생성: %s (%dx%d, %.1fKB)\n", $path, $w, $h, filesize($path) / 1024);
}

/**
 * 스토어 아이콘 512x512.
 *
 * 투명을 쓰지 않는다 — 플레이가 알아서 둥근 마스크를 씌우므로 배경을 꽉 채우고,
 * 마크는 잘리지 않을 만큼 안으로 들인다.
 */
function renderStoreIcon(string $path): void
{
    $s = 512 * SUPERSAMPLE;
    $im = imagecreatetruecolor($s, $s);
    imagefilledrectangle($im, 0, 0, $s, $s, allocate($im, COLOR_BG));

    // 런처 아이콘(inset 1.0)과 같은 비율로 그린다 — 마크 자체의 여백(21%)이
    // 이미 충분해서 플레이가 모서리를 깎아도 셀이 잘리지 않는다.
    drawMark($im, 0, 0, $s, false);

    downsampleAndSave($im, 512, 512, $path);
    imagedestroy($im);
}

/** 글자 폭을 재서 목표 폭에 맞는 포인트 크기를 찾는다 (한글은 글자마다 폭이 달라 계산으로는 안 된다) */
function fitPointSize(string $text, string $font, float $maxWidth, float $startPt): float
{
    for ($pt = $startPt; $pt > 6; $pt -= 0.5) {
        $box = imagettfbbox($pt, 0, $font, $text);
        if (($box[2] - $box[0]) <= $maxWidth) {
            return $pt;
        }
    }

    return 6;
}

/**
 * 그래픽 이미지 1024x500 — 좌측에 마크, 우측에 이름과 한 줄 설명.
 *
 * 플레이가 기기·위치에 따라 가장자리를 잘라내므로 안쪽 여백을 넉넉히 두고,
 * 글자는 실제 렌더 폭을 재서 남는 폭에 맞춘다.
 */
function renderFeatureGraphic(string $path): void
{
    $w = 1024 * SUPERSAMPLE;
    $h = 500 * SUPERSAMPLE;
    $margin = $w * 0.075;

    $im = imagecreatetruecolor($w, $h);
    imagefilledrectangle($im, 0, 0, $w, $h, allocate($im, COLOR_BG));

    // 하단 강조선 — 장식은 이것 하나로 충분하다. 잘려도 정보를 잃지 않는다.
    imagefilledrectangle($im, 0, (int) ($h - $h * 0.018), $w, $h, allocate($im, COLOR_ACCENT));

    $box = $h * 0.40;
    $markX = $margin;
    drawMark($im, $markX, ($h - $box) / 2, $box, true);

    $textX = (int) ($markX + $box + $w * 0.05);
    $maxText = $w - $textX - $margin;

    $title = allocate($im, COLOR_TEXT);
    $muted = allocate($im, COLOR_MUTED);

    $titleText = '온라인 심사 시스템';
    $subText = '종이 없는 심사 · 자동 집계 · 결재용 최종집계표';
    $urlText = 'judge.sw4u.kr';

    $titlePt = fitPointSize($titleText, FONT_BOLD, $maxText, 62 * SUPERSAMPLE);
    $subPt = fitPointSize($subText, FONT_REGULAR, $maxText, 26 * SUPERSAMPLE);
    $urlPt = fitPointSize($urlText, FONT_REGULAR, $maxText, 22 * SUPERSAMPLE);

    imagettftext($im, $titlePt, 0, $textX, (int) ($h * 0.45), $title, FONT_BOLD, $titleText);
    imagettftext($im, $subPt, 0, $textX, (int) ($h * 0.60), $muted, FONT_REGULAR, $subText);
    imagettftext($im, $urlPt, 0, $textX, (int) ($h * 0.73), $muted, FONT_REGULAR, $urlText);

    downsampleAndSave($im, 1024, 500, $path);
    imagedestroy($im);
}

foreach ([FONT_BOLD, FONT_REGULAR] as $font) {
    if (! is_file($font)) {
        fwrite(STDERR, "폰트를 찾을 수 없습니다: {$font}\n");
        exit(1);
    }
}

$dir = dirname(__DIR__).'/store';

if (! is_dir($dir) && ! mkdir($dir, 0o755, true) && ! is_dir($dir)) {
    fwrite(STDERR, "디렉터리를 만들 수 없습니다: {$dir}\n");
    exit(1);
}

renderStoreIcon("{$dir}/icon-512.png");
renderFeatureGraphic("{$dir}/feature-graphic-1024x500.png");

echo "\n스크린샷은 실제 기기에서 찍어 같은 폴더에 넣으세요 (최소 2장).\n";
