"use strict";

window.onload=function(){
    var A = {};

    A["Ё"]="JO";A["Й"]="J";A["Ц"]="TS";A["У"]="U";A["К"]="K";A["Е"]="E";A["Н"]="N";A["Г"]="G";A["Ш"]="Š";A["Щ"]="Štš";A["З"]="Z";A["Х"]="H";
    A["ё"]="jo";A["й"]="j";A["ц"]="ts";A["у"]="u";A["к"]="k";A["е"]="e";A["н"]="n";A["г"]="g";A["ш"]="š";A["щ"]="štš";A["з"]="z";A["х"]="h";
    A["Ф"]="F";A["Ы"]="Õ";A["В"]="V";A["А"]="A";A["П"]="P";A["Р"]="R";A["О"]="O";A["Л"]="L";A["Д"]="D";A["Ж"]="Ž";A["Э"]="E";
    A["ф"]="f";A["ы"]="õ";A["в"]="v";A["а"]="a";A["п"]="p";A["р"]="r";A["о"]="o";A["л"]="l";A["д"]="d";A["ж"]="ž";A["э"]="e";
    A["Я"]="Ja";A["Ч"]="Tš";A["С"]="S";A["М"]="M";A["И"]="I";A["Т"]="T";A["Б"]="B";A["Ю"]="Ju";
    A["я"]="ja";A["ч"]="tš";A["с"]="s";A["м"]="m";A["и"]="i";A["т"]="t";A["б"]="b";A["ю"]="ju";

    function replaceCyrillicWithLatinInInputForm(input) {

	var inputText = input.value;
	inputText = transliterate(inputText);
	input.value = inputText;

    }

    function transliterate(word) {
	var result = '';

	for (var i = 0; i < word.length; i++) {
            var char = word.charAt(i);

            result += A[char] || char;
	}
	return result;
    }

    try {
	var inputFirstName = document.getElementById("newTeacherFirstName");
	var inputLastName = document.getElementById("newTeacherLastName");

	inputFirstName.onkeyup = function() {replaceCyrillicWithLatinInInputForm(inputFirstName)};
	inputLastName.onkeyup = function() {replaceCyrillicWithLatinInInputForm(inputLastName)};
    } catch (err) {
	//TODO
    }

    var txtFile = new XMLHttpRequest();
    var url = "/js/profs";
    txtFile.open("GET", url + ((/\?/).test(url) ? "&" : "?") + (new Date()).getTime());
    txtFile.overrideMimeType('text/plain');
    txtFile.onreadystatechange = function() {
    	if (txtFile.readyState === 4) {  // Makes sure the document is ready to parse.
    	    if (txtFile.status === 200) {  // Makes sure it's found the file.
    		var allText = txtFile.responseText;
		unescape(encodeURIComponent(allText));
    		var lines = txtFile.responseText.split("\n"); // Will separate each line into an array
		try {
		    var inputSearchName = document.getElementById("searchName");
		    inputSearchName.onkeyup = function() {replaceCyrillicWithLatinInInputForm(inputSearchName)};
		    new Awesomplete(inputSearchName, {
			list: lines,
			maxItems: 5,
		    });
		} catch(err) {
		    //TODO
		}
    	    }
    	}
    }
    txtFile.send(null);
};

window.addEventListener("awesomplete-select", function(e){
    window.location = '?action=read&name=' + e['text'];
}, false);
