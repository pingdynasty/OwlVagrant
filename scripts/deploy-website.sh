#!/bin/bash
#
# Written by Sam Artuso <sam@highoctanedev.co.uk>

# Settings
CLONE_DIR='OwlServer'
REPO_URL="https://github.com/pingdynasty/$CLONE_DIR.git"

# Make sure only root can run this script
if [[ $EUID -ne 0 ]]; then
    echo "$0 $1 This script must be run as root" 1>&2
    exit 1
fi

# Work out directory where this script is, no matter where it is called from,
# and with which method (source, bash -c, symlinks, etc.):
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
echo "$0 $1 $DIR is the DIR"

# Work out environment
HOSTNAME=`hostname`
if [ "$HOSTNAME" = "ulrike" -o "$HOSTNAME" = "bella" ]
then
    TARGET_ENV='staging'
    GIT_BRANCH='dev'
    SITE_URL='http://staging.hoxtonowl.com'
elif [ "$HOSTNAME" = "nestor" ]
then
    TARGET_ENV='production'
    GIT_BRANCH='master'
    SITE_URL='http://www.hoxtonowl.com'
else
    echo "$0 $1 Unknown hostname $HOSTNAME. Cannot determine target environment."
    echo "$0 $1 Aborting."
    exit 1
fi
echo "$0 $1 This is $HOSTNAME, assuming $TARGET_ENV environment."

# Delete previous clone
rm -rf $DIR/$CLONE_DIR

# Clone repository
echo "$0 $1 Cloning $CLONE_DIR repository..."
git clone --quiet $REPO_URL $DIR/$CLONE_DIR
cd $DIR/$CLONE_DIR
echo "$0 $1 Checking out '$GIT_BRANCH' branch..."
git checkout $GIT_BRANCH > /dev/null
git pull origin $GIT_BRANCH > /dev/null
cd - > /dev/null

# Update Wordpress
echo "$0 $1 Updating Wordpress files..."
rm -rf $DIR/../httpdocs/wp-content/themes/hoxton-owl-2014
mkdir -p $DIR/../httpdocs/wp-content/themes/
mv $DIR/$CLONE_DIR/web/wordpress/wp-content/themes/hoxton-owl-2014/ $DIR/../httpdocs/wp-content/themes/
cp -a $DIR/$CLONE_DIR/web/wordpress/robots.txt $DIR/../httpdocs/
mkdir -p $DIR/../httpdocs/wp-content/plugins/
cp $DIR/$CLONE_DIR/web/wordpress/wp-content/plugins/owl-api-bridge.php $DIR/../httpdocs/wp-content/plugins/
cp $DIR/$CLONE_DIR/web/wordpress/wp-content/plugins/owl-patch-uploader.php $DIR/../httpdocs/wp-content/plugins/
cp $DIR/$CLONE_DIR/web/wordpress/wp-content/plugins/README.owl.md $DIR/../httpdocs/wp-content/plugins/

# Update Mediawiki
echo "$0 $1 Updating Mediawiki files..."
mkdir -p $DIR/../httpdocs/mediawiki/skins/
rsync --quiet -avz $DIR/$CLONE_DIR/web/mediawiki/skins/HoxtonOWL2014 $DIR/../httpdocs/mediawiki/skins/

# Update patch builder script
echo "$0 $1 Updating patch builder script..."
mkdir -p $DIR/../patch-builder/
cp -a $DIR/$CLONE_DIR/web/scripts/patch-builder/patch-builder.php $DIR/../patch-builder/
cp -a $DIR/$CLONE_DIR/web/scripts/patch-builder/build-all.php $DIR/../patch-builder/
cp -a $DIR/$CLONE_DIR/web/scripts/patch-builder/common.php $DIR/../patch-builder/
cp -a $DIR/$CLONE_DIR/web/scripts/patch-builder/composer.json $DIR/../patch-builder/
cp -a $DIR/$CLONE_DIR/web/scripts/patch-builder/composer.lock $DIR/../patch-builder/
cd $DIR/../patch-builder/
composer install
cd - > /dev/null

# Update deployment script
#echo "$0 $1 Updating deployment script..."
#cp -a $DIR/$CLONE_DIR/web/scripts/deployment/deploy-website.sh $DIR/
#cp -a $DIR/$CLONE_DIR/web/README.md $DIR/..

# Set privileges
echo "$0 $1 Setting up permissions..."
chown -R root $DIR/../httpdocs
chgrp -R hoxtonowl $DIR/../httpdocs
find $DIR/../httpdocs -type f -exec chmod 664 '{}' \;
find $DIR/../httpdocs -type d -exec chmod 775 '{}' \;
find $DIR/../httpdocs -type d -exec chmod g+s '{}' \;
mkdir -p $DIR/../httpdocs/wp-content/uploads
chown -R www-data $DIR/../httpdocs/wp-content/uploads
mkdir -p $DIR/../httpdocs/mediawiki/images
chown -R www-data $DIR/../httpdocs/mediawiki/images
chown -R www-data:www-data $DIR/../patch-builder
chmod -R a+r $DIR/../patch-builder
chmod a+x $DIR/../patch-builder
if [ "$TARGET_ENV" = "production" ]
then
    chmod -R o+w $DIR/../httpdocs/piwik/tmp
fi

chown -R root:root $DIR/../deployment
chmod 755 $DIR/../deployment
chmod 744 $DIR/../deployment/deploy-website.sh

mkdir -p $DIR/../logs
chown -R www-data:www-data $DIR/../logs
chmod -f 664 $DIR/../logs/*

# Delete temp repo clone
# echo "$0 $1 Deleting temp repo clone..."
# rm -rf $DIR/$CLONE_DIR
