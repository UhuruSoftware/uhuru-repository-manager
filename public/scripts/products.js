//
//      Methods used for switching the panels inside the products page.
//

function showUcc()
{
    document.getElementById('ucc').style.display = 'block';
    document.getElementById('stemcell').style.display = 'none';
    document.getElementById('software').style.display = 'none';
}
function showStemcell()
{
    document.getElementById('ucc').style.display = 'none';
    document.getElementById('stemcell').style.display = 'block';
    document.getElementById('software').style.display = 'none';
}
function showSoftware()
{
    document.getElementById('ucc').style.display = 'none';
    document.getElementById('stemcell').style.display = 'none';
    document.getElementById('software').style.display = 'block';
}