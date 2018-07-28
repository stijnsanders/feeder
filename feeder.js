function doResize(){
  var x=document.getElementById("postview");
  x.width=window.innerWidth-x.offsetLeft*2;
  x.height=window.innerHeight-x.offsetTop*2.4;
}
function doPost(x,event){
  var e=(window.event||event);
  if(e.ctrlKey||e.shiftKey)
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
var outOfView="";
var markRead="";
var scrollNotify=0;
var trailer;
var gotMore=false;
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
        outOfView+=p[i].id;
      }
      else
        j++;
    i++;
  }
  if(outOfView!=""){
    scrollNotify=window.setTimeout(function(){
      markRead+=outOfView;
      outOfView="";
      $.get('Read.xxm?'+markRead,function(x){
        markRead="";
        var xx=x.split(":");
        if(xx[0]=="OK")document.getElementById("postcount").textContent=xx[2];
      }).fail(function(){
        document.getElementById("postcount").style.backgroundColor="#FF0000";
      });
    },500);
  }
  if(!gotMore){
    if(!trailer)trailer=document.getElementById("trailer");
    if(trailer.offsetTop<window.scrollY+window.innerHeight*1.5){
      gotMore=true;
      $.get('?x='+trailer.getAttribute("x")+'&'+document.location.href.split("?")[1],function(x){
        if(x!="-"){
          var y=x.length;
          while(y!=0&&x[y-1]!=";")y--;
          trailer.setAttribute("x",x.slice(y));
          $(trailer).before(x.slice(0,y-1));
          gotMore=false;
        }
      });
    }
  }
};
function doPostLoad(){
  if(document.getElementById("postview").contentWindow.location.href=="about:blank")
    doPostHide();
}