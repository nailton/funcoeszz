# ----------------------------------------------------------------------------
# http://cbn.globoradio.com.br
# Busca e toca os últimos comentários dos comentaristas da radio CBN.
# Uso: zzcbn [--audio] -c COMENTARISTA [-d data] ou  zzcbn --lista
# Ex.: zzcbn -c max-gehringer -d ontem
#      zzcbn -c juca-kfouri -d 13/05/09
#      zzcbn -c miriam
#      zzcbn --audio -c  mario-sergio-cortella -d 16/02/2015
#
# Autor: Rafael Machado Casali <rmcasali (a) gmail com>
# Desde: 2009-04-16
# Versão: 4
# Licença: GPL
# Requisitos: zzecho zzplay zzcapitalize zzdatafmt
# ----------------------------------------------------------------------------
zzcbn ()
{
	zzzz -h cbn "$1" && return

	local cache=$(zztool cache cbn)
	local url='http://cbn.globoradio.globo.com'
	local audio=0
	local nome comentarista link fonte rss podcast ordem data_coment data_audio

	#Verificacao dos parâmetros
	test -n "$1" || { zztool uso cbn; return 1; }

	# Cache com parametros para nomes e links
	if ! test -s "$cache" || test $(date -r "$cache" +%F) != $(date +%F)
	then
		$ZZWWWHTML "$url" |
		sed -n '/lista-menu-item comentaristas/,/lista-menu-item boletins/p' |
		zzxml --tag a |
		sed -n '/http:..cbn.globoradio.globo.com.comentaristas./{s/.*="//;s/">//;/-e-/d;p;}' |
		awk -F "/" '{url = $0;gsub(/-/," ", $6); gsub(/\.htm/,"", $6);printf "%s;%s;%s\n", $6, $5, url }'|
		while read linha
		do
			nome=$(echo "$linha" | cut -d ";" -f 1 | zzcapitalize )
			comentarista=$(echo "$linha" | cut -d ";" -f 2 )
			link=$(echo "$linha" | cut -d ";" -f 3 )
			fonte=$($ZZWWWHTML "$link")
			rss=$(
				echo "$fonte" |
				grep 'cbn/rss' |
				sed 's/.*href="//;s/".*//'
			)
			podcast=$(
				echo "$fonte" |
				grep 'cbn/podcast' |
				sed 's/.*href="//;s/".*//'
			)
			echo "$nome | $comentarista | $rss | $podcast"
		done > "$cache"
	fi

	# Listagem dos comentaristas
	if test "$1" = "--lista"
	then
		awk -F " [|] " '{print $2 "\t => " $1}' "$cache" | expand -t 28
		return
	fi

# Opções de linha de comando
	while test "${1#-}" != "$1"
	do
		case "$1" in
			-c)
				comentarista="$2"
				shift
				shift
			;;
			-d)
				data_coment=$(zzdatafmt --en -f "SSS, DD MMM AAAA" "$2")
				data_audio=$(zzdatafmt -f "_AAMMDD" "$2")
				shift
				shift
			;;
			--audio)
				audio=1
				shift
				if test -n "$1"
				then
					if zztool testa_numero "$1"
					then
						num_audio="$1"
						shift
					fi
				fi
			;;
			*)
				zzecho -l vermelha "Opção inválida!!"
				return 1
			;;
		esac
	done

	# Audio ou comentários feitos pelo comentarista selecionado
	if test "$audio" -eq 1
	then
		podcast=$(
			sed -n "/$comentarista/p" "$cache" |
			cut -d'|' -f 4| tr -d ' '
		)
		if test -n "$podcast"
		then
			podcast=$($ZZWWWHTML "$podcast" | grep 'media:content')
			zztool eco "Áudios diponíveis:"
			echo "$podcast" |
			sed 's/.*_//; s/\.mp3.*//; s/\(..\)\(..\)\(..\)/\3\/\2\/20\1/' |
			awk '{ print NR ".", $0}'

			podcast=$(
				echo "$podcast" |
				if test -n "$data_audio"
				then
					sed -n "/${data_audio}/p"
				else
					head -n 1
				fi |
				sed 's|.*audio=|http://download.sgr.globo.com/sgr-mp3/cbn/|' |
				sed 's/\.mp3.*/.mp3/'
			)

			test -n "$podcast" && zzplay "$podcast" mplayer || zzecho -l vermelho "Sem comentários em áudio."
		else
			zzecho -l vermelho "Sem comentários em áudio."
		fi

	else
		rss=$(
			sed -n "/$comentarista/p" "$cache" |
			cut -d'|' -f 3 | tr -d ' '
		)

		if test -n "$rss"
		then
			$ZZWWWHTML "$rss" |
			zzxml --tag item |
			zzxml --tag title --tag description --tag pubDate |
			sed 's/<title>/-----/' |
			zzxml --untag |
			sed '/^$/d; s/ [0-2][0-9]:.*//' |
			if test -n "$data_coment"
			then
				grep -B 3 "$data_coment"
			else
				cat -
			fi
		else
			zzecho -l vermelho "Sem comentários."
		fi
	fi
}
