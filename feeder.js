function doResize(){
  var x=document.getElementById("postview");
  var y=document.getElementById("black");
  x.width=window.innerWidth-x.offsetLeft*2;
  x.height=window.innerHeight-x.offsetTop*2.4;
  y.style.width=window.innerWidth+"px";
  y.style.height=window.innerHeight+"px";
}
var currentPostLink=null;
function doPost(x,event){
  var e=(window.event||event);
  if(e.ctrlKey||e.shiftKey)
    return true;
  else {
    document.body.style.overflowX="hidden";
    document.body.style.overflowY="hidden";
    document.getElementById("black").style.display="";
    document.getElementById("postbox").style.display="";
    document.getElementById("postview").style.display="";
    document.getElementById("postlink").href=x.href;
    var p=x.parentElement;
    currentPostLink=p;
    window.open("Post.xxm"+x.getAttribute("postqs"),"postview");
    if(p.className=="post"){
      p.className="postread";
      var c=document.getElementById("postcount");
      c.textContent=c.textContent-1;
    }
    window.onresize=doResize;
    doResize();
    return false;
  }
}
function doPostHide(){
  document.getElementById("black").style.display="none";
  document.getElementById("postbox").style.display="none";
  document.getElementById("postview").style.display="none";
  document.body.style.overflowX="";
  document.body.style.overflowY="scroll";
  currentPostLink=null;
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
function doNext(){
  var p=null;
  if(currentPostLink)p=currentPostLink.nextSibling;
  while(p&&p.id.substr(0,1)!="p")
    p=p.nextSibling;
  if(p){
    document.body.onscroll=doScroll1;
    var h1=p.offsetTop+p.offsetHeight+4;
    var h2=window.scrollY+window.innerHeight;
    if(h1>h2)
      window.scrollBy(0,h1-h2);
    currentPostLink=p;
    var x=p.lastElementChild;//assert "A"
    document.getElementById("postlink").href=x.href;
    //window.open("Post.xxm"+x.getAttribute("postqs"),"postview");
    document.getElementById("postview").contentWindow.location.replace("Post.xxm"+x.getAttribute("postqs"));
    if(p.className=="post"){
      p.className="postread";
      var c=document.getElementById("postcount");
      c.textContent=c.textContent-1;
    }
  }
  else
    doClose();
  return false;
}
var outOfView="";
var markRead="";
var scrollNotify=0;
var trailer;
var gotMore=false;
function doScroll1(){
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
      fetch('Read.xxm?'+markRead,{
        credentials:"include",
        cache:"no-cache"
      }).then(function(r){
        markRead="";
        r.text().then(function(x){
          var xx=x.split(":");
          if(xx[0]=="OK"){
            var pc=document.getElementById("postcount");
            pc.textContent=xx[2];
            pc.style.backgroundColor="";
          }
        });
      }).catch(function(ee){
        var pc=document.getElementById("postcount");
        pc.title=ee;
        pc.style.backgroundColor="#FF0000";
      });
    },500);
  }
  if(!gotMore){
    if(!trailer)trailer=document.getElementById("trailer");
    if(trailer.offsetTop<window.scrollY+window.innerHeight*1.5){
      gotMore=true;
      fetch('?x='+trailer.getAttribute("x")+'&'+document.location.href.split("?")[1],{
        credentials:"include",
        cache:"no-cache"
      }).then(function(r){
        r.text().then(function(x){
          if(x!="-"){ 
            var y=x.length;
            while(y!=0&&x[y-1]!=";")y--;
            trailer.setAttribute("x",x.slice(y));
            trailer.insertAdjacentHTML("beforebegin",x.slice(0,y-1));
            gotMore=false;
          }
        });
      });
    }
  }
}
function doScroll0(){
  if(window.scrollY<25){
    document.body.onscroll=doScroll1;
    doScroll1();
    document.getElementById("postcount").style.backgroundColor="";
  }
}
function doScroll(){
  if(window.scrollY>100){
    document.body.onscroll=doScroll0;
    document.getElementById("postcount").style.backgroundColor="#999999";
  }else{
    document.body.onscroll=doScroll1;
    doScroll1();
  }
}
function doPostLoad(){
  if(document.getElementById("postview").contentWindow.location.href=="about:blank")
    doPostHide();
}