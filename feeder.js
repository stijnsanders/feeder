function doResize(){
  var x=document.getElementById("postview");
  x.width=window.innerWidth-x.offsetLeft*2;
  x.height=window.innerHeight-x.offsetTop*2.4;
}
function doPost(x){
  if(window.event.ctrlKey||window.event.shiftKey)
    return true;
  else {
    document.body.style.overflow="hidden";
    document.getElementById("black").style.display="";
    document.getElementById("postbox").style.display="";
    document.getElementById("postview").style.display="";
    document.getElementById("postlink").href=x.href;
    window.open("Post.xxm"+x.getAttribute("postqs"),"postview");
    x.parentElement.className="postread";
    window.onresize=doResize;
    doResize();
    var c=document.getElementById("postcount");
    c.textContent=c.textContent-1;
    return false;
  }
}
function doPostHide(){
  document.getElementById("black").style.display="none";
  document.getElementById("postbox").style.display="none";
  document.getElementById("postview").style.display="none";
  document.body.style.overflow="scroll";
}
function doClose(){
  window.open("about:blank","postview");
  doPostHide();
  return false;
}
function doHere(){
  window.open(document.getElementById("postlink").href,"postview");
  return false;
}
var outOfView=[];
var scrollNotify=0;
var doneFS=false;
function doScroll(){
  if(scrollNotify!=0){
    window.clearTimeout(scrollNotify);
    scrollNotify=0;
  }
  var p=document.body.children;
  var i=0;
  var j=0;
  while(i<p.length&&j<8){
    if(p[i].className=="post")
      if(p[i].offsetTop<window.scrollY){
        p[i].className="postread";
        outOfView.push(p[i].id);
      }
      else
        j++;
    i++;
  }
  scrollNotify=window.setTimeout(function(){
    scrollNotify=0;
    $.get('Read.xxm?'+outOfView.join(""),function(x){
      var xx=x.split(":");
      if(xx[0]=="OK")document.getElementById("postcount").textContent=xx[2];
    });
    outOfView=[];
  },500);
};
function doPostLoad(){
  if(document.getElementById("postview").contentWindow.location.href=="about:blank")
    doPostHide();
}