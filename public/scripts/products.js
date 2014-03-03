//
//      Methods used for switching the panels inside the products page.
//

function showProductType(type)
{
    Session.set('product_type', 'ucc');

    if (type == 'ucc')
    {
        document.getElementById('ucc').style.display = 'none';
        document.getElementById('stemcell').style.display = 'none';
        document.getElementById('software').style.display = 'none';
        document.getElementById('ucc').style.display = 'inline-block';
        Session.set('product_type', 'ucc');
    }

    if (type == 'stemcell')
    {
        document.getElementById('ucc').style.display = 'none';
        document.getElementById('stemcell').style.display = 'none';
        document.getElementById('software').style.display = 'none';
        document.getElementById('stemcell').style.display = 'inline-block';
        Session.set('product_type', 'stemcell');
    }

    if (type == 'software')
    {
        document.getElementById('ucc').style.display = 'none';
        document.getElementById('stemcell').style.display = 'none';
        document.getElementById('software').style.display = 'none';
        document.getElementById('software').style.display = 'inline-block';
        Session.set('product_type', 'software');
    }
}

function getSelectedProductType()
{
    return Session.get('product_type');
}


function showProperties()
{
    document.getElementById('properties_panel').style.display = 'block';
    document.getElementById('versions_panel').style.display = 'none';
}

function showVersions()
{
    document.getElementById('versions_panel').style.display = 'block';
    document.getElementById('properties_panel').style.display = 'none';
}


function showVersionDetails()
{
    document.getElementById('version_details').style.display = 'block';
    document.getElementById('version_dependencies').style.display = 'none';
}

function showVersionDependencies()
{
    document.getElementById('version_dependencies').style.display = 'block';
    document.getElementById('version_details').style.display = 'none';
}

function showNewVersion()
{
    document.getElementById('add_version_form').style.display = 'block';
    document.getElementById('add_version_via_sftp_form').style.display = 'none';
}
function showNewVersionViaSftp()
{
    document.getElementById('add_version_form').style.display = 'none';
    document.getElementById('add_version_via_sftp_form').style.display = 'block';
}

//
// Methods used to store and persist variables across website pages
//
if (JSON && JSON.stringify && JSON.parse) var Session = Session || (function() {

    var win = window.top || window;
    var store = (win.name ? JSON.parse(win.name) : {});

    function Save() {
        win.name = JSON.stringify(store);
    }

    if (window.addEventListener) window.addEventListener("unload", Save, false);
    else if (window.attachEvent) window.attachEvent("onunload", Save);
    else window.onunload = Save;

    return {
        set: function(name, value) {
            store[name] = value;
        },
        get: function(name) {
            return (store[name] ? store[name] : undefined);
        },
        clear: function() { store = {}; },
        dump: function() { return JSON.stringify(store); }
    };

})();