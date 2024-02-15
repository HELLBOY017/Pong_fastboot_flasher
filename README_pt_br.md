# Nothing Phone (2) Fastboot ROM Flasher

### Começando
- Este é um script para tornar conveniente para o usuário retornar à ROM stock ou desbloquear seu dispositivo sob qualquer circunstância em que o tamanho da partição super não tenha sido alterada (se a ROM flashada estiver usando o mesmo tamanho da partição super que a ROM stock, então esse script sempre funcionará, o que supostamente é seguido por todas as ROMs personalizadas). Este script é bastante útil quando as recuperações personalizadas não conseguem atualizar a ROM stock, onde geralmente enfrentam erros devido ao particionamento confuso na partição super. Este script também pode ser modificado para flashar ROMs personalizadas e pode ser usado em ROMs que enviam o firmware stock.

### Uso
- Certifique-se de descompactar o ZIP ota stock completo e depois descompactar o `payload.bin` usando [payload_dumper_go](https://github.com/ssut/payload-dumper-go) e então coloque o script adequado ao seu sistema operacional no diretório onde os arquivos `*.img` de `payload.bin` foram extraídos. Finalmente reinicie o seu dispositivo no bootloader e então

  execute o script clicando duas vezes no arquivo `flash_all.bat` no Windows

  ou fazendo isso em um sistema operacional Linux no terminal após abrir o terminal no diretório onde os arquivos `*.img` de `payload.bin` foram extraídos:

```bash
chmod +x flash_all.sh && bash flash_all.sh
```

### Observações
- Para Linux, os utilitários wget e unzip devem estar instalados em seu sistema.
- O script atualiza a ROM no slot A e destrói as partições no slot B para criar espaço para as partições que estão sendo atualizadas no slot A. Esta é a razão pela qual não incluímos a capacidade de trocar de slot, pois as partições seriam destruídas no slot inativo e é por isso que o script atualiza as partições no slot primário, que é o slot A.
