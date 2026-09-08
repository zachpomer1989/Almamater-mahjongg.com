<?php
/**
 * Applied by apply-seo-fixes.sh via `wp eval-file`. Not meant to run alone.
 *
 * Reads the reviewed .tsv files, writes meta descriptions, sets product tags
 * to noindex, noindexes the Coming Soon page, removes the three malformed
 * tags, and deactivates the unconfigured login-logo snippet.
 *
 * Every value it overwrites is captured to backup.json first.
 */

$repo = getenv( 'REVIEW_REPO' );
$bk   = getenv( 'REVIEW_BACKUP' );
if ( ! $repo || ! $bk ) {
	echo "!! REVIEW_REPO / REVIEW_BACKUP not set\n";
	return;
}

$backup = array(
	'generated'  => gmdate( 'c' ),
	'post_meta'  => array(),
	'taxonomy'   => null,
	'titles'     => null,
	'tags'       => array(),
	'wpcode'     => array(),
);

/** Read a TSV, skipping blanks and # comments. */
function amm_read_tsv( $path ) {
	$out = array();
	if ( ! is_readable( $path ) ) {
		return $out;
	}
	foreach ( file( $path, FILE_IGNORE_NEW_LINES ) as $line ) {
		if ( $line === '' || $line[0] === '#' ) {
			continue;
		}
		$out[] = explode( "\t", $line );
	}
	return $out;
}

// ---- 1. Meta descriptions on pages and products --------------------
echo "--- Meta descriptions: posts ---\n";
$n = 0;
foreach ( amm_read_tsv( "$repo/fixes/meta-posts.tsv" ) as $row ) {
	if ( count( $row ) < 2 ) {
		continue;
	}
	$id   = (int) trim( $row[0] );
	$desc = trim( $row[1] );
	$post = get_post( $id );
	if ( ! $post ) {
		echo "  !! post $id not found, skipped\n";
		continue;
	}
	$backup['post_meta'][ $id ] = get_post_meta( $id, '_yoast_wpseo_metadesc', true );
	update_post_meta( $id, '_yoast_wpseo_metadesc', $desc );
	echo "  OK  $id  " . mb_strlen( $desc ) . " chars  " . $post->post_title . "\n";
	$n++;
}
echo "  $n updated\n\n";

// ---- 2. Meta descriptions on product categories --------------------
// Yoast keeps term SEO in the wpseo_taxonomy_meta option, not termmeta.
echo "--- Meta descriptions: product categories ---\n";
$tax_meta         = get_option( 'wpseo_taxonomy_meta', array() );
$backup['taxonomy'] = $tax_meta;
$n = 0;
foreach ( amm_read_tsv( "$repo/fixes/meta-terms.tsv" ) as $row ) {
	if ( count( $row ) < 3 ) {
		continue;
	}
	list( $taxonomy, $slug, $desc ) = array( trim( $row[0] ), trim( $row[1] ), trim( $row[2] ) );
	$term = get_term_by( 'slug', $slug, $taxonomy );
	if ( ! $term ) {
		echo "  !! $taxonomy/$slug not found, skipped\n";
		continue;
	}
	if ( ! isset( $tax_meta[ $taxonomy ] ) ) {
		$tax_meta[ $taxonomy ] = array();
	}
	if ( ! isset( $tax_meta[ $taxonomy ][ $term->term_id ] ) ) {
		$tax_meta[ $taxonomy ][ $term->term_id ] = array();
	}
	$tax_meta[ $taxonomy ][ $term->term_id ]['wpseo_desc'] = $desc;
	echo "  OK  $slug  " . mb_strlen( $desc ) . " chars\n";
	$n++;
}
update_option( 'wpseo_taxonomy_meta', $tax_meta );
echo "  $n updated\n\n";

// ---- 3. Product tags to noindex ------------------------------------
// 13 tags across 6 products means most tag archives hold a single item.
echo "--- Product tag archives ---\n";
$titles           = get_option( 'wpseo_titles', array() );
$backup['titles'] = $titles;
$titles['noindex-tax-product_tag'] = true;
update_option( 'wpseo_titles', $titles );
echo "  OK  product tags set to noindex\n\n";

// ---- 4. Coming Soon page to noindex --------------------------------
echo "--- Coming Soon page ---\n";
$cs = get_page_by_path( 'coming-soon' );
if ( $cs ) {
	$backup['post_meta'][ $cs->ID . '_noindex' ] = get_post_meta( $cs->ID, '_yoast_wpseo_meta-robots-noindex', true );
	update_post_meta( $cs->ID, '_yoast_wpseo_meta-robots-noindex', '1' );
	echo "  OK  {$cs->ID} set to noindex\n\n";
} else {
	echo "  -- coming-soon page not found\n\n";
}

// ---- 5. Remove the malformed tags ----------------------------------
// The WooCommerce CSV import split on commas; the source used semicolons,
// so each whole string became one tag.
echo "--- Malformed product tags ---\n";
$bad = array(
	'ecueast-carolinapiratescollege-mahjong',
	'meredith-collegecollege-mahjong',
	'nc-statewolfpackcollege-mahjong',
);
foreach ( $bad as $slug ) {
	$term = get_term_by( 'slug', $slug, 'product_tag' );
	if ( ! $term ) {
		echo "  -- $slug not found (already gone)\n";
		continue;
	}
	$backup['tags'][] = array(
		'term_id' => $term->term_id,
		'name'    => $term->name,
		'slug'    => $term->slug,
		'count'   => $term->count,
	);
	wp_delete_term( $term->term_id, 'product_tag' );
	echo "  OK  deleted: {$term->name}\n";
}
echo "\n";

// ---- 6. Deactivate the unconfigured login-logo snippet -------------
// It still points at WPCode's demo image, a stock real estate logo on a
// free image host.
echo "--- WPCode login logo snippet ---\n";
$snips = get_posts( array(
	'post_type'      => 'wpcode',
	'post_status'    => 'any',
	'posts_per_page' => 50,
	's'              => 'Login Page',
) );
$found = false;
foreach ( $snips as $s ) {
	if ( stripos( $s->post_title, 'Logo on Login' ) === false ) {
		continue;
	}
	$found = true;
	$backup['wpcode'][] = array( 'ID' => $s->ID, 'status' => $s->post_status, 'title' => $s->post_title );
	if ( $s->post_status === 'publish' ) {
		wp_update_post( array( 'ID' => $s->ID, 'post_status' => 'draft' ) );
		echo "  OK  deactivated: {$s->post_title}\n";
	} else {
		echo "  -- already inactive: {$s->post_title}\n";
	}
}
if ( ! $found ) {
	echo "  -- snippet not found\n";
}
echo "\n";

file_put_contents( "$bk/backup.json", wp_json_encode( $backup, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE ) );
echo "Backup written to $bk/backup.json\n";
