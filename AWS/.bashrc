# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
        . /etc/bashrc
fi

# User specific aliases and functions
alias c=clear

function ec2PublicIP
{
        /opt/aws/bin/ec2-metadata| grep public-ipv4 | cut -d":" -f2 | sed 's/^[ \t]*//;s/[ \t]*$//'
}
export PS1='[\u@`ec2PublicIP`:\w]$ 
